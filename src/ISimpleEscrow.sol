// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ISimpleEscrow{

    /// @notice Emitted when a new deal is registered
    /// @param _uniqueId A unique Id is assigned to the deal
    /// @param _sellerWallet Address of the seller 
    /// @param _arbitratorAddress Address of the arbitrator
    /// @param _buyerAddress Address of the arbitrator
    event DealRegistered(
        uint256 indexed _uniqueId,
        address indexed _sellerWallet, 
        address indexed _arbitratorAddress,
        address _buyerAddress
        );
    
    /// @notice Emitted when a current deal changes status
    /// @param _uniqueId A unique Id is assigned to the deal
    /// @param _sellerWallet Address of the seller 
    /// @param _buyerWallet Address of the buyer 
    /// @param _arbitratorAddress Address of the arbitrator
    event DealStatusChanged(
        uint256 indexed _uniqueId, 
        address indexed _sellerWallet, 
        address indexed _buyerWallet, 
        address _arbitratorAddress
        );

    /// @notice Emitted when a deal is appealed by the buyer
    /// @param _uniqueId A unique Id is assigned to the deal 
    /// @param _arbitratorAddress Address of the arbitrator
    event DealAppealed(
        uint256 indexed _uniqueId,  
        address indexed _arbitratorAddress
        );
    
    /// @notice Emmited when the owner changes
    /// @param previousOwner Address of the previous owner 
    /// @param newOwner Address of the new owner
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    /// @notice Registers a fresh deal
    /// @dev `Buyer(`msg.sender`) makes a deal (`DealDetails`) and includes it in `dealDetailsMap` 
    ///     with `uniqueId` as the key
    /// @param _sellerWallet The address of the seller
    /// @param _amount The deal amount .
    /// @param _termsAndConditionsHash Keccak-256 hash of the terms and conditions
    ///     NOTE: Terms and conditions have to be communnicated off-chain with only it's hash stored on-chain 
    /// @param _communicationChannelDetails Email, PhoneNumber etc as means of communication between the tri-party 
    ///     NOTE: Send an empty string if you would like to keep this info off-chain
    /// @param _arbitratorAddress The address of the arbitrator 
    /// @param _arbitorCommision Commision amount of the arbitrator 
    function registerDeal(
        address _sellerWallet, 
        uint256 _amount, 
        bytes32 _termsAndConditionsHash, 
        string memory _communicationChannelDetails, 
        address _arbitratorAddress, 
        uint256 _arbitorCommision
    ) external payable;
    
    /// @notice Transfer protocol ownership to a new address
    /// @dev New address can't be address(0)
    function transferOwnership(address newOwner) external;

    /// @notice Withdraw eth owed
    function withdraw() external;

    /// @notice Seller offers a full refund
    /// @dev Only seller can call
    /// Changes status of the deal to `REFUNDED`. Updates `sellerDealsMap` of the seller wallet  
    /// @param _uniqueId Id of the deal
    function refund(uint256 _uniqueId) external;
    
    /// @notice Buyer appeals to the arbitrator
    /// @dev Only buyer can call
    /// Changes status of the deal to `PENDING_ARBITRATOR`. Updates `sellerDealsMap` of the seller wallet
    /// @param _uniqueId Id of the deal
    function appealToArbitrator(uint256 _uniqueId) external;

    /// @notice Buyer closes the deal with no issues 
    /// @dev Only buyer can call
    /// Changes status of the deal to CLOSED_WITHOUT_ISSUE. Updates `sellerDealsMap` of the seller wallet
    /// @param _uniqueId Id of the deal
    function closeDealWithoutIssue(uint256 _uniqueId) external;

    /// @notice Arbitrator closes the deal after an investigation. Funds are awarded to the seller. 
    /// Remaining funds are returned to the buyer. Arbitrator recieves a commision  
    /// @dev Only arbitrator can call
    /// Deal is updated with `award`, `comments` hash
    /// Funds of arbitrator, buyer and seller are updated in `addressBalance`
    /// Changes status of the deal to CLOSED_WITH_ARBITRATOR. 
    /// Updates `sellerDealsMap` of the seller wallet.
    /// @param _uniqueId Id of the deal 
    /// @param _award Amount of funds to be released to the seller 
    /// @param _comments Hash of the comments made by arbitrator about the deal 
    function closeDealWithArbitrator(uint256 _uniqueId, uint256 _award, bytes32 _comments) external;

}

