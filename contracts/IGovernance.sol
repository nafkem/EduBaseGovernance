// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

interface IGovernance {
    
    function registerStudent ( address _student, string memory _imageIPSFHash) external;
    function requestGrant (string memory _title, string memory _description, uint256 _amount, string memory _imageIPFSHash, string memory _institution, address _student)external;
    function userWithdrawGrant (uint256 _grantID) external;
    function clostGrant (uint256 _grantID) external;
    function donate (uint256 _amount, uint256 _grantID) external;
    // function riskAssessorWithdrawInsurance (uint _idClaimRequests) external returns (uint _insuranceID, uint refund); 
    function depositGovernanceFee (uint _amount)external;
     function createProposal(string memory description, uint256 amountRequired) external;
    function addMember(address _member, uint256 _votePower) external;

}