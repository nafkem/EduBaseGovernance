// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IEduBase {
    function getTopStudents() external view returns (address[] memory);
}

contract EduBaseGovernance is Ownable, ReentrancyGuard, Pausable, ERC721 {

    IERC20 public _nativeToken;
    IEduBase public eduBaseContract;
    uint256 public minimumVotesRequired = 100;
    uint256 public proposalDeadline = 14 days;
    uint256 public nftTokenId;  // Counter for NFT Token IDs
    
    struct GrantRequest {
        uint256 id;
        address student;
        uint256 amountRequested;
        uint256 votesFor;
        uint256 votesAgainst;
        bool approved;
        bool claimed;
        bool closed;
        mapping(address => bool) hasVoted;
    }

    struct GrantRequestDetails {
        uint256 id;
        address student;
        uint256 amountRequested;
        uint256 votesFor;
        uint256 votesAgainst;
        bool approved;
        bool claimed;
        bool closed;
    }
    // Declare the memberData mapping
    mapping(address => Member) public memberData;
    

    enum ProposalStatus { Pending, Denied, Approved, Closed, Executed }

    struct Proposal {
        uint256 id;
        string description;
        uint256 voteCount;
        uint256 amountRequired;
        bool executed;
        ProposalStatus status;
        address[] eligibleStudents;
    }
    struct Member {
    address memberAddress;
    MembershipTier tier;
    uint256 engagementReward;
    uint256 NFTId;
    bool joined;
    uint256 votePower;
}
enum MembershipTier { Bronze, Silver, Gold, Diamond }

    uint256 public grantCount;
    uint256 public proposalCount;
    uint256 public totalGrantsClaimed;
    mapping(address => bool) public isMember;  // Mapping to track donors and members
    mapping(address => uint256[]) public proposalMap;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => GrantRequest) private grants;

    event DonationReceived(address indexed donor, uint256 amount, uint256 proposalID);
    event GrantRequested(uint256 indexed grantId, address indexed student, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, string description, uint256 amountRequired);
    event GrantApproved(uint256 indexed grantId, address indexed student, uint256 amount);
    event GrantClaimed(uint256 indexed grantId, address indexed student, uint256 amount);
    event GrantRejected(uint256 indexed grantId);
    event Voted(address indexed voter, uint256 indexed grantId, bool support);
    event NFTAwarded(address indexed recipient, uint256 tokenId);

    modifier onlyMember() {
        require(isMember[msg.sender], "Not a valid member");
        _;
    }

    modifier onlyStudent() {
        // Assumes EduBase has a function to verify if an address is a student
        require(eduBaseContract.getTopStudents().length > 0, "Caller is not a student");
        _;
    }

   constructor(address tokenAddress) ERC721("EduGovernanceNFT", "EDU-NFT") Ownable(msg.sender) {
    _nativeToken = IERC20(tokenAddress);
    require(tokenAddress != address(0), "Invalid token address");
}
    // Function to create a proposal by top-performing students
    function createProposal(string memory description, uint256 amountRequired)
     external onlyStudent {
        address[] memory topStudents = eduBaseContract.getTopStudents();
        //require(amountRequired > 0, "Amount must be greater than zero");

        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            description: description,
            voteCount: 0,
            amountRequired: amountRequired,
            executed: false,
            status: ProposalStatus.Pending,
            eligibleStudents: topStudents
        });

        emit ProposalCreated(proposalCount, description, amountRequired);
    }

    // Vote on a proposal
    function voteOnProposal(uint256 proposalId, bool support) external onlyMember {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Pending, "Proposal not open for voting");

        proposal.voteCount += support ? 1 : 0;  // Adjust vote count based on support

        if (proposal.voteCount >= minimumVotesRequired) {
            proposal.status = ProposalStatus.Approved;
        }
    }

    // Admin can approve a proposal and initiate grant request
    function approveProposal(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Approved, "Proposal not approved");
        proposal.status = ProposalStatus.Closed;

        // Create a grant request for the proposal amount
        uint256 grantId = grantCount++;
        GrantRequest storage newGrant = grants[grantId];
        newGrant.id = grantId;
        newGrant.student = msg.sender; // Admin can assign to the lead student of top performers
        newGrant.amountRequested = proposal.amountRequired;
        newGrant.approved = true;

        emit GrantApproved(grantId, newGrant.student, proposal.amountRequired);
    }

    // Claim the approved grant
    function claimGrant(uint256 grantId) external nonReentrant onlyStudent {
        GrantRequest storage grant = grants[grantId];
        require(grant.approved, "Grant not approved");
        require(!grant.claimed, "Grant already claimed");
        require(msg.sender == grant.student, "Not authorized");

        grant.claimed = true;
        totalGrantsClaimed += grant.amountRequested;
        _nativeToken.transfer(msg.sender, grant.amountRequested);

        // Mint NFT to the student who claims the grant
        nftTokenId++;
        _mint(msg.sender, nftTokenId);
        emit NFTAwarded(msg.sender, nftTokenId);

        emit GrantClaimed(grantId, msg.sender, grant.amountRequested);
    }

    // Function to handle donations for specific proposals
    function donateToProposal(uint256 proposalId, uint256 amount) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Pending, "Proposal not accepting donations");
        _nativeToken.transferFrom(msg.sender, address(this), amount);

        // Mint NFT to the donor
        nftTokenId++;
        _mint(msg.sender, nftTokenId);
        emit NFTAwarded(msg.sender, nftTokenId);

        emit DonationReceived(msg.sender, amount, proposalId);
    }

   function addMember(address _member, uint256 _votePower) external onlyOwner {
    // Logic to add member to the governance with vote power
    Member memory newMember = Member({
        memberAddress: _member,
        tier: MembershipTier.Bronze, // Default tier or as required
        engagementReward: 0,
        NFTId: 0,
        joined: true,
        votePower: _votePower
    });
    memberData[_member] = newMember;
}

    // Set EduBase contract
    function setEduBaseContract(address eduBaseAddress) external onlyOwner {
        eduBaseContract = IEduBase(eduBaseAddress);
    }

    // Get proposal details
    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    // Get all top-performing students from EduBase
    function getTopStudentsFromEduBase() external view returns (address[] memory) {
        return eduBaseContract.getTopStudents();
    }
}
