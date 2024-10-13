// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./EduBaseGovernance.sol";
import "./IGovernance.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract EduBase is ReentrancyGuard, Ownable, Pausable {
    IERC20 public _nativeToken;
    uint256 private studentCount;
    IGovernance public governance;
    uint256 private instructorCount;
    uint256 private verifiedInstructorCount;
    uint256 public courseCount = 0; // Track course IDs

    address public admin;
    address[] private verifiedInstructors;

    enum VerificationState {
        PENDING,
        VERIFIED
    }

    struct Instructor {
        address id;
        bool verified;
        VerificationState verificationState;
    }

    struct Student {
        uint256 cgpa;
        address student;
        string transcript;
        bool inDept;
    }

    struct Course {
        string courseName;
        address instructor;
        bool approvedByAdmin;
    }

    struct ExamRequest {
        address student;
        bool approved;
    }

    struct ExamResult {
        address student;
        uint256 score;
        bool submitted;
        bool disputed; // To indicate if there's a dispute
    }

    event ScoreSubmitted(address indexed student, uint256 score);
    event ScoreDisputed(address indexed student, uint256 score);
    event ScoreVerified(address indexed student, uint256 score);
    event ScoreSubmissionPaused(address indexed admin);
    event ScoreSubmissionResumed(address indexed admin);
    event StudentRegistered(address indexed student, string indexed matricNumber);
    event InstructorRegistered(address indexed instructor, uint256 indexed experience);
    event InstructorVerified(address indexed admin, address indexed instructor);
    event ExamResultSubmitted(address indexed student, uint256 score);
    event ExamStartedByStudent(address indexed student, uint256 indexed courseId);
    event ExamApproved(address indexed instructor, uint256 indexed courseId);
    event StudentEnrolledInCourse(address indexed student, uint indexed courseId);
    event CourseRegistered(uint indexed courseId, string courseName, address instructor);
    event Revoked(address indexed studentAddress, uint256 timestamp);
    event Donation(address indexed donor, uint256 amount, uint256 timestamp);

    mapping(uint => Course) public courses;
    mapping(address => uint[]) public studentCourses;
    mapping(address => Student) public students;
    mapping(string => address) public matricToAddress;
    mapping(uint => ExamRequest) public examRequests;
    mapping(address => ExamResult) public examResults;
    mapping(address => bool) public isStudent;
    mapping(address => bool) public isInstructor;
    mapping(address => bool) public isInstructorVerified;
    mapping(address => string) public instructorDetails;
    mapping(address => string) public studentDetails;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyInstructor() {
        require(isInstructor[msg.sender], "Not an instructor");
        _;
    }

    modifier onlyVerifiedInstructors() {
        require(isInstructorVerified[msg.sender], "Not a verified instructor");
        _;
    }

    modifier onlyStudent() {
        require(isStudent[msg.sender], "Only a student can call this function");
        _;
    }

constructor(address tokenAddress, address governanceContractAddress) Ownable(msg.sender) {
    _nativeToken = IERC20(tokenAddress);
    governance = IGovernance(governanceContractAddress); // Use interface for casting
    admin = msg.sender;
}



    // Prevent contract from receiving Ether
    receive() external payable {
        revert("EduBase does not accept Ether");
    }

    fallback() external {
        revert("EduBase does not accept Ether");
    }

    // Register & Verify Students
    function registerStudent(string memory matricNumber, address studentAddress,
     string memory ipfsHash)  external onlyAdmin {
        require(studentAddress != address(0), "Invalid student address");
        require(!isStudent[studentAddress], "Student already registered");

        isStudent[studentAddress] = true;
        matricToAddress[matricNumber] = studentAddress;
        studentDetails[studentAddress] = ipfsHash;

        emit StudentRegistered(studentAddress, matricNumber);
    }

    // Register & Verify Instructors
    function registerInstructor(address instructorAddress, uint256 experience, 
    string memory ipfsHash) public onlyAdmin {
        require(!isInstructor[instructorAddress], "Instructor already registered");
        isInstructor[instructorAddress] = true;
        instructorDetails[instructorAddress] = ipfsHash;
        
        emit InstructorRegistered(instructorAddress, experience);
    }

    function verifyInstructor(address instructorAddress) external onlyAdmin {
        require(isInstructor[instructorAddress], "Not a registered instructor");
        isInstructorVerified[instructorAddress] = true;
        emit InstructorVerified(msg.sender, instructorAddress);
    }

    // Course Registration & Enrollment
    function registerCourse(string memory courseName) external onlyInstructor {
        courseCount++;
        courses[courseCount] = Course(courseName, msg.sender, false);
        emit CourseRegistered(courseCount, courseName, msg.sender);
    }

    function approveCourse(uint courseId) external onlyAdmin {
        require(isCourseValid(courseId), "Invalid course ID");
        courses[courseId].approvedByAdmin = true;
    }

    function enrollInCourse(uint courseId) external onlyStudent {
        require(isCourseValid(courseId), "Invalid course ID");
        require(courses[courseId].approvedByAdmin, "Course not approved");
        studentCourses[msg.sender].push(courseId);
        emit StudentEnrolledInCourse(msg.sender, courseId);
    }

    // Exam Flow: Start, Approve, Submit Results
    function startExam(uint256 courseId) external onlyStudent {
        require(isStudentEnrolledInCourse(courseId, msg.sender), "Not enrolled in the course");
        examRequests[courseId] = ExamRequest({ student: msg.sender, approved: false });
        emit ExamStartedByStudent(msg.sender, courseId);
    }

    function approveExam(uint256 courseId) external onlyVerifiedInstructors {
        require(courses[courseId].instructor == msg.sender, "Only instructor can approve");
        examRequests[courseId].approved = true;
        emit ExamApproved(msg.sender, courseId);
    }

    function submitExamResult(uint256 score) external onlyVerifiedInstructors {
        require(!examResults[msg.sender].submitted, "Score already submitted");
        examResults[msg.sender] = ExamResult({
            student: msg.sender,
            score: score,
            submitted: true,
            disputed: false
        });
        emit ScoreSubmitted(msg.sender, score);
    }

    // Score Verification & Management
    function updateScoreHistory(address student, uint256 score) external onlyVerifiedInstructors {
        require(isStudent[student], "Invalid student");
        examResults[student].score = score;
    }

    function disputeScore() external onlyStudent {
        require(examResults[msg.sender].submitted, "No score submitted");
        examResults[msg.sender].disputed = true;
        emit ScoreDisputed(msg.sender, examResults[msg.sender].score);
    }

    function verifyScore(address student) external onlyVerifiedInstructors {
        require(examResults[student].submitted, "No score submitted");
        emit ScoreVerified(student, examResults[student].score);
    }

    // Utility Functions
    function isCourseValid(uint courseId) internal view returns (bool) {
        return (courseId > 0 && courseId <= courseCount);
    }

    function isStudentEnrolledInCourse(uint courseId, address studentAddress) internal view returns (bool) {
        for (uint i = 0; i < studentCourses[studentAddress].length; i++) {
            if (studentCourses[studentAddress][i] == courseId) {
                return true;
            }
        }
        return false;
    }
     
    // Function to set the governance contract (can only be set by admin/owner)
    // function setGovernanceContract(address _governanceAddress) external onlyAdmin {
    //     governance = EduBaseGovernance(_governanceAddress);
    // }
   
    function createStudentProposal(address _students, string memory description, 
    uint256 amountRequired)  external onlyStudent {
    // Logic to validate that these students are eligible
    governance.createProposal(description, amountRequired);
}
function addMemberToGovernance(address _member, uint256 _votePower) external onlyAdmin {
    governance.addMember(_member, _votePower);
}

    function pauseScoreSubmissions() external onlyVerifiedInstructors {
        _pause();
        emit ScoreSubmissionPaused(msg.sender);
    }

    function resumeScoreSubmissions() external onlyVerifiedInstructors {
        _unpause();
        emit ScoreSubmissionResumed(msg.sender);
    }
}
