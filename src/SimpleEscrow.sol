// SPDX-License-Identifier: MIT
pragma solidity  0.8.26;

import './ISimpleEscrow.sol';


/// @title Ethereum based escrow system. 
/// @author Rajvardhan Takle
/// @notice Use this contract to setup an arbitrator to release funds on delivery of goods/services.
/// Overview: 
/// - There are 4 parties involved in this escrow system - buyer, seller, arbitrator and a protocol owner. 
/// - A deal is registered between a buyer and a seller,
///   it includes various details including the amount and an arbitrator's wallet address.
///   Funds are sent to this contract by the buyer during the registration only.
/// - Upon delivery of goods/service, buyer can release the funds to the seller without involving the arbitrator.
/// - Alternatively a buyer can appeal to the arbitrator. 
///   The arbitrator after investigation can then release funds(ranging from 0 to the deal amount)
///   to the seller at his discretion. 
/// - The arbitrator gets a commision when a deal is appealed by the buyer. 
/// - The seller can offer a refund at any time except when the deal is already closed. 
contract EscrowCollection is ISimpleEscrow{ 
    // A unique contiguous id assigned to each deal  
    uint256 public uniqueId; 

    // Protocol commision in BPS. 1 BPS = 0.01%
    uint16 public  PROTOCOL_COMMISION_BPS;
    // A minimum fee collected at the time of deal registreation
    uint256 public  PROTOCOL_BASE_FEE;  
    // Address of the protocol owner
    address public  PROTOCOL_OWNER;

    // Balances of all addresses owed funds
    mapping(address => uint256) public addressBalance;
    
    enum DecisionStatus {
        /*
        * Used in `DealDetails.dealDecision` 
        * Only `DEAL_IN_PROGRESS` and `PENDING_ARBITRATOR` are considered open deals, 
        * rest are closed deals. 
        */
        // Status whenever a new deal is made
        DEAL_IN_PROGRESS, 
        // Status whenever seller gives a refund 
        REFUNDED,
        // Status whenever a deal has been appealed by the buyer
        PENDING_ARBITRATOR, 
        // Status whenever a buyer closes the deal 
        CLOSED_WITHOUT_ISSUE, 
        // Status whenever an arbitrator closes the deal
        CLOSED_WITH_ARBITRATOR
    }
    
    struct Decision{ 
        // Current `DecisionStatus` of the deal
        DecisionStatus dealDecision;
        // Amount awarded to the seller by the arbitrator
        uint256 award;
        // Keccak256 hash of the comments made by arbitrator about the deal
        bytes32 comments;
    }

    struct DealDetails{ 
        // Id assigned to the deal
        uint256 uniqueId;
        // Buyer wallet address
        address buyerWallet;
        // Seller wallet adrress
        address sellerWallet;
        // The amount of funds the seller is supposed to recieve from the buyer
        uint256 dealAmount;
        // Keccak256 hash of the terms and conditions of the agreement between buyer and seller 
        bytes32 termsAndConditionsHash; 
        // Any communication details furnished by the buyer (Not strictly enforced)
        string communicationChannelDetails;
        // Address of the arbitrator
        address arbitratorAddress; 
        // Details regarding the decision about the deal
        Decision Decision;
        // Commision given to the arbitrator
        uint256 arbitorCommision; 
        // Fee given to the protocol on top of the base fee.
        uint256 addedProtocolFee;
        // Seller count at the time of making the deal
        uint256 sellerCount;
    }

    // Mapping of: deal id -> DealDetails
    mapping(uint256 => DealDetails) public dealDetailsMap;

    // Mapping of: sellerWallet -> seller count -> deal id
    mapping(address => mapping(uint256 => uint256)) public sellerDealsMap;

    // Number of deals made by the seller mapped to his wallet
    mapping(address => uint256) public sellerDealCount;


    /// @dev Prevents calling a function from anyone except the deal buyer
    modifier onlyDealBuyer(uint256 _uniqueId) {
        DealDetails storage _DealDetails = dealDetailsMap[_uniqueId];
        require(_DealDetails.buyerWallet==msg.sender, "Only buyer can call this function");
        _;
    }

    /// @dev Prevents calling a function from anyone except the deal seller
    modifier onlyDealSeller(uint256 _uniqueId) {
        DealDetails storage _DealDetails = dealDetailsMap[_uniqueId];
        require(_DealDetails.sellerWallet==msg.sender, "Only seller can call this function");
        _;
    }

    /// @dev Prevents calling a function from anyone except the deal arbitrator
    modifier onlyDealArbitrator(uint256 _uniqueId) {
        DealDetails storage _DealDetails = dealDetailsMap[_uniqueId];
        require(_DealDetails.arbitratorAddress==msg.sender, "Only arbitrator can call this function");
        _;
    }

    /// @dev Prevents closed deals to be reopened.
    modifier onlyOpenDeal(uint256 _uniqueId) {
        require(
            !isDealClosed(_uniqueId),
            "Deal is already closed"
        ); 
        _;
    }

    /// @dev Modifier to restrict access to protocol owner only.
    modifier onlyOwner() {
        require(msg.sender == PROTOCOL_OWNER, "Ownable: caller is not the owner");
        _;
    }

    constructor(uint16 _PROTOCOL_COMMISION_BPS, uint256 _PROTOCOL_BASE_FEE){
        
        require(_PROTOCOL_COMMISION_BPS<10000, "Protocol can't take commision more than equal to the deal amount");

        PROTOCOL_COMMISION_BPS = _PROTOCOL_COMMISION_BPS;
        PROTOCOL_BASE_FEE = _PROTOCOL_BASE_FEE ;
        PROTOCOL_OWNER = msg.sender;
        emit OwnershipTransferred(address(0), PROTOCOL_OWNER);

    }

    /// @inheritdoc ISimpleEscrow
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner can't be the zero address");
        PROTOCOL_OWNER = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }

    /// @inheritdoc ISimpleEscrow
    function registerDeal(
        address _sellerWallet,
        uint256 _amount,
        bytes32 _termsAndConditionsHash, 
        string memory _communicationChannelDetails, 
        address _arbitratorAddress, 
        uint256 _arbitorCommision
    ) external payable {

        // The deal amount supplied .
        uint256 dealAmount = _amount;

        // Calculate Protocol fee as percentage of the raw deal amount .
        uint256 addedProtocolFee = ((PROTOCOL_COMMISION_BPS*dealAmount)/10000);
      
        require(msg.sender != _sellerWallet, "You can't make a deal with yourself");
        require(msg.sender != _arbitratorAddress, "Buyer can't be the arbitrator");
        require(_sellerWallet != _arbitratorAddress, "Seller can't be the arbitrator");
        require(msg.value>=_arbitorCommision + PROTOCOL_BASE_FEE + addedProtocolFee + dealAmount,
        "Funds can't be less than equal to the arbitors commision + protocol base fee");
        require(dealAmount > 0, "Deal amount should be atleast 1 wei");
        
        // Extra msg.value 
        uint256 excessAmt = msg.value - _arbitorCommision - PROTOCOL_BASE_FEE - addedProtocolFee - dealAmount;
        
        // // Increment deal id 
        uniqueId += 1;

        // // Update number of deals made by the seller 
        sellerDealCount[_sellerWallet]+=1;
        
        // // Fill in all the deal details 
        DealDetails memory _DealDetails = DealDetails({ 
            uniqueId: uniqueId,
            buyerWallet: msg.sender,
            sellerWallet: _sellerWallet,
            dealAmount: dealAmount,
            termsAndConditionsHash: _termsAndConditionsHash,
            communicationChannelDetails: _communicationChannelDetails,
            arbitratorAddress: _arbitratorAddress,
            Decision: Decision({
            dealDecision: DecisionStatus.DEAL_IN_PROGRESS,
            award: 0,
            comments: 0
        }),
            sellerCount: sellerDealCount[_sellerWallet],
            arbitorCommision: _arbitorCommision,
            addedProtocolFee: addedProtocolFee
        });
        
        // Map the deal to it's deal id 
        dealDetailsMap[uniqueId] = _DealDetails;

        // Give protocol fee to the protocol owner
        addressBalance[PROTOCOL_OWNER] += (PROTOCOL_BASE_FEE + addedProtocolFee);
        
        // Map the sellers wallet to the deal id through the latest seller deal count 
        updateSellerStats(uniqueId);
        
        // Give back excess ether to the buyer 
        payable(msg.sender).transfer(excessAmt);

        emit DealRegistered(uniqueId, _sellerWallet, _arbitratorAddress, msg.sender);

    }

    /// @dev Allows all owed parties to witdraw eth
    function withdraw() external { 
    require(addressBalance[msg.sender] > 0,"Nothing to withdraw");
    
    uint256 _callerBalance = addressBalance[msg.sender];

    // Reset callers balance to 0 wei
    addressBalance[msg.sender]=0;

    // Send funds to callers balance 
    payable(msg.sender).transfer(_callerBalance);

    }

    /// @inheritdoc ISimpleEscrow
    function refund(uint256 _uniqueId) external onlyOpenDeal(_uniqueId) onlyDealSeller(_uniqueId){ 

        DealDetails storage _DealDetails = dealDetailsMap[_uniqueId];

        // Arbitrator should get his commision if refund is given when decision is appealed 
        if(_DealDetails.Decision.dealDecision == DecisionStatus.PENDING_ARBITRATOR)
        {
        // Give commision to the arbitrator 
        addressBalance[_DealDetails.arbitratorAddress]+=_DealDetails.arbitorCommision;
        // Give deal amount  to the buyer 
        addressBalance[_DealDetails.buyerWallet] += (_DealDetails.dealAmount);
        }
        else{
        // Give deal amnount and arbitrator commision to the buyer 
        addressBalance[_DealDetails.buyerWallet] += (_DealDetails.dealAmount + _DealDetails.arbitorCommision); 
        }

        // Close the deal with changing deal status
        _DealDetails.Decision.dealDecision = DecisionStatus.REFUNDED;

        // Update seller stats 
        updateSellerStats(_uniqueId);

        emit DealStatusChanged(
            uniqueId, 
            _DealDetails.sellerWallet, 
            _DealDetails.buyerWallet, 
            _DealDetails.arbitratorAddress
        );


    }
    
    /// @inheritdoc ISimpleEscrow
    function appealToArbitrator(uint256 _uniqueId) external onlyDealBuyer(_uniqueId){

        DealDetails storage _DealDetails = dealDetailsMap[_uniqueId];
        
        require(_DealDetails.Decision.dealDecision == DecisionStatus.DEAL_IN_PROGRESS,
        "Only DEAL_IN_PROGRESS can be appealed");

        // Keep deal open pending arbitrator decision
        _DealDetails.Decision.dealDecision = DecisionStatus.PENDING_ARBITRATOR;

        // Update seller stats 
        updateSellerStats(_uniqueId);

        emit DealStatusChanged(
            uniqueId, 
            _DealDetails.sellerWallet, 
            _DealDetails.buyerWallet, 
            _DealDetails.arbitratorAddress
        );

        emit DealAppealed(uniqueId, _DealDetails.arbitratorAddress);

    }

    /// @inheritdoc ISimpleEscrow
    function closeDealWithoutIssue(uint256 _uniqueId) external onlyOpenDeal(_uniqueId) onlyDealBuyer(_uniqueId) {

        DealDetails storage _DealDetails = dealDetailsMap[_uniqueId];

        // Arbitrator should get his commision if refund is given when decision is appealed . 
        if(_DealDetails.Decision.dealDecision == DecisionStatus.PENDING_ARBITRATOR)
        {
        // Give commision to the arbitrator 
        addressBalance[_DealDetails.arbitratorAddress] += _DealDetails.arbitorCommision;
        }
        else{
        // Give arbitrator commision to the buyer 
        addressBalance[_DealDetails.buyerWallet] +=  _DealDetails.arbitorCommision; 
        }
        
        // Give deal funds to seller
        addressBalance[_DealDetails.sellerWallet] += (_DealDetails.dealAmount); 
        
        // Close deal with no issues
        _DealDetails.Decision.dealDecision = DecisionStatus.CLOSED_WITHOUT_ISSUE;

        // Update seller stats 
        updateSellerStats(_uniqueId);

        emit DealStatusChanged(
            uniqueId, 
            _DealDetails.sellerWallet, 
            _DealDetails.buyerWallet, 
            _DealDetails.arbitratorAddress
        );

    }

    /// @inheritdoc ISimpleEscrow
    function closeDealWithArbitrator(
        uint256 _uniqueId, 
        uint256 _award, 
        bytes32 _comments
        ) external onlyDealArbitrator(_uniqueId) {
        
        DealDetails storage _DealDetails = dealDetailsMap[_uniqueId];
        
        require(
        DecisionStatus.PENDING_ARBITRATOR == _DealDetails.Decision.dealDecision,
        "Arbitrator can only intervene when a deal is appealed"
        );

        require(_award <= _DealDetails.dealAmount, "Awarded amount can't be greater than the deal amount");
        
        // Change details to show funds awarded to the seller by the arbitrator
        _DealDetails.Decision.award = _award;

        // Give funds awarded by arbitrator to the seller
        addressBalance[_DealDetails.sellerWallet] += _award;

        // Give commision to the arbitrator for reaching a decision 
        addressBalance[msg.sender] += _DealDetails.arbitorCommision;

        // Return balance funds to the buyer 
        addressBalance[_DealDetails.buyerWallet] += (_DealDetails.dealAmount-_award);

        // Add arbitrator comment hash
        _DealDetails.Decision.comments = _comments;
        
        // Change the status of the deal to show that it's closed by the arbitrator
        _DealDetails.Decision.dealDecision = DecisionStatus.CLOSED_WITH_ARBITRATOR;

        // Update seller stats 
        updateSellerStats(_uniqueId);

        emit DealStatusChanged(
            uniqueId, 
            _DealDetails.sellerWallet, 
            _DealDetails.buyerWallet, 
            _DealDetails.arbitratorAddress
        );

    }

    /// @notice Calculate the amount of eth to send to make a deal of `amount` with certain arbitrator commision 
    /// @param _dealAmount The amount seller is supposed to receive from the buyer 
    /// @param _arbitratorCommision Commision given to the arbitrator 
    function calculateMsgValue(
        uint256 _dealAmount, 
        uint256 _arbitratorCommision
        ) public view returns (uint256 calculatedMsgValue){ 
        require(_dealAmount>0, "Deal can't be less than 1 wei");
        uint256 addedProtocolFee=((_dealAmount*PROTOCOL_COMMISION_BPS)/10000);
        uint256 msgValue = _dealAmount + _arbitratorCommision + PROTOCOL_BASE_FEE + addedProtocolFee;
        return msgValue;
    }  

    /// @notice Check if a deal is closed 
    /// @dev PENDING_ARBITRATOR` and `DEAL_IN_PROGRESS` are considered open deals. Rest are closed   
    /// @param _uniqueId Id of the deal.
    /// @return `true` if deal is closed . `false` otherwise 
    function isDealClosed(uint256 _uniqueId) public view returns (bool){ 
            
            DealDetails storage _DealDetails = dealDetailsMap[_uniqueId];
            
            if(_DealDetails.Decision.dealDecision==DecisionStatus.DEAL_IN_PROGRESS || 
            _DealDetails.Decision.dealDecision==DecisionStatus.PENDING_ARBITRATOR ){ 
                return false;
            }
            
            return true;
        
    }
        
    /// @notice Updates sellers deals 
    /// @dev Mapping of seller wallet -> seller deals count -> deal id 
    function updateSellerStats(uint256 _uniqueId) internal { 
        
        DealDetails memory _DealDetails =  dealDetailsMap[_uniqueId];
       
        // Link seller wallet to deal id 
        sellerDealsMap[_DealDetails.sellerWallet][_DealDetails.sellerCount] = _uniqueId;

    }

}
