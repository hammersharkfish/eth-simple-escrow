// SPDX-License-Identifier: MIT
pragma solidity  0.8.26;

import "forge-std/Test.sol";
import "../src/SimpleEscrow.sol";



contract SimpleEscrowTest is Test {

    // Pre-determined party addresses
    address fixedArbAddress = 0x00000000000000000000000000000000000000AB;
    address fixedSellAddress = 0x00000000000000000000000000000000000000dd;
    address fixedBuyAddress = 0x00000000000000000000000000000000000000bb;
    address fixedProtocolAddress = 0x00000000000000000000000000000000000000cc;

    // `1 ether` used as gas
    uint256 someEther = 1000000000000000000;

    // Set sample deal parameters 
    uint256 _sampleDealAmt = 23423423423423423;
    bytes32 _sampleTermsAndConditionsHash = 0xdbef85571eb7136ea9625de2edfe8133b3c1bb0778a1cd1323a7235a1f2865ea;
    string _samplecommunicationChannelDetails = "example.com";
    uint256 _sampleArbitorCommision = 423423423423423;
    uint256 _sampleMsgValue = 93423423423423423;
    uint256 _sampleAward = 1011011;
    bytes32 _sampleComments = 0x6afe59acaeee6a0c5b15fbf09994cd9533a19c8a2952a1960ffd320c68ba95af;

    // Protocol parameters
    uint256 PROTOCOL_COMMISION_BPS;
    uint256 PROTOCOL_BASE_FEE;

    // Balances of the four parties
    WalletAmountsStruct PreRegistrationBalances;
    struct WalletAmountsStruct{ 
        uint256 fixedArbAddressAmount;
        uint256 fixedSellAddressAmount;
        uint256 fixedBuyAddressAmount;
        uint256 fixedProtocolAddressAmount;
    }

    EscrowCollection escrowCollection;
    function setUp() public {
        
        // Give protocol owner 1 ether for gas
        vm.deal(fixedProtocolAddress, someEther);
        // Set protocol owner as 0x00000000000000000000000000000000000000cc
        vm.prank(fixedProtocolAddress);        

        escrowCollection = new EscrowCollection(
        123, 
        1000000000000011
        );

        // Ensure that the prank is applied and transaction is completed before setting another prank
        vm.stopPrank();

        PROTOCOL_COMMISION_BPS = escrowCollection.PROTOCOL_COMMISION_BPS();
        PROTOCOL_BASE_FEE = escrowCollection.PROTOCOL_BASE_FEE(); 
        
        // Balance before a deal is registered  
        PreRegistrationBalances = getPartiesLatestWithdrawlAmounts();

    }

    function testCheckUpdateSellerStats() external{ 
        registerSampleDealFixedAddresses();
        registerSampleDealFixedAddresses();
        registerSampleDeal(fixedBuyAddress, 0x000000000000000000000000000000000000ABcD, fixedArbAddress);
        registerSampleDealFixedAddresses();
        assertEq(escrowCollection.sellerDealCount(fixedSellAddress), 3);

        assertEq(escrowCollection.sellerDealsMap(fixedSellAddress,1), 1);
        assertEq(escrowCollection.sellerDealsMap(fixedSellAddress, 2), 2);
        assertEq(escrowCollection.sellerDealsMap(fixedSellAddress, 3), 4);


    }
    function getPartiesLatestWithdrawlAmounts() public view returns (WalletAmountsStruct memory _WalletAmountStruct){
        return WalletAmountsStruct({ 
        fixedArbAddressAmount: escrowCollection.addressBalance(fixedArbAddress),
        fixedSellAddressAmount: escrowCollection.addressBalance(fixedSellAddress),
        fixedBuyAddressAmount: escrowCollection.addressBalance(fixedBuyAddress), 
        fixedProtocolAddressAmount: escrowCollection.addressBalance(fixedProtocolAddress)
        });
    }

    function registerSampleDeal(address _buyerAddress, address _sellerAddress, address _arbAddress) public payable{ 
        // Give _sampleMsgValue amount of wei 
        vm.deal(_buyerAddress, _sampleMsgValue); 

        // Use vm.prank to set the sender of the transaction as nbuyer
        vm.prank(_buyerAddress);

        // Register a sample deal
        escrowCollection.registerDeal{value: _sampleMsgValue}(        
        _sellerAddress,
        _sampleDealAmt,
        _sampleTermsAndConditionsHash, 
        _samplecommunicationChannelDetails, 
        _arbAddress, 
        _sampleArbitorCommision
        );

        // Ensure that the prank is applied and transaction is completed before setting another prank
        vm.stopPrank();

    }

    function registerSampleDealFixedAddresses() public payable{ 
        registerSampleDeal(fixedBuyAddress, fixedSellAddress, fixedArbAddress);  
    }

    function testFuzz_CalculateMsgValue(uint256 _dealAmount, uint256 _arbCommision) public view {       
        
        // Set the constraints for fuzzing inputs
        vm.assume(_dealAmount <= 120000000*(10**20));
        vm.assume(_dealAmount > 0);
        vm.assume(_arbCommision <= 120000000*(10**20));        

        uint256 msgValue = 
        escrowCollection.calculateMsgValue(
        _dealAmount, 
        _arbCommision
        );
        
        // Check if msgValue retuned by calculator matches correct amount 
        assertEq(msgValue, _dealAmount + _arbCommision + PROTOCOL_BASE_FEE + 
        (PROTOCOL_COMMISION_BPS*_dealAmount)/10000);
        
    }
    function testFuzzRegisterDeal(        
        uint256 _amount,
        bytes32 _termsAndConditionsHash, 
        string memory _communicationChannelDetails, 
        uint256 _arbitorCommision,
        uint256 _msgValue
        ) public payable { 
        

        // Set the constraints for fuzzing inputs
        vm.assume(_amount <= 120000000*(10**20));
        vm.assume(_amount > 0);
        vm.assume(_arbitorCommision<= 120000000*(10**20));
        
        uint256 addedProtocolFee = ((PROTOCOL_COMMISION_BPS*_amount)/10000);

        uint256 _minVal =  PROTOCOL_BASE_FEE + (2*120000000*(10**20)) + addedProtocolFee;
        uint256 _maxVal = 2*_minVal;
        _msgValue = bound(_msgValue, _minVal, _maxVal );
        address _arbitratorAddress = fixedArbAddress;
        address _sellerWallet = fixedSellAddress;
      
       
        vm.deal(fixedBuyAddress, _msgValue); // Ensure balance is high enough
            
        uint256 preUniqueId = escrowCollection.uniqueId();
        uint256 _sellerDealCount = escrowCollection.sellerDealCount(_sellerWallet);

        // Use vm.prank to set the sender of the transaction
        vm.prank(fixedBuyAddress);
                
        escrowCollection.registerDeal{value: _msgValue}(        
        _sellerWallet,
        _amount,
        _termsAndConditionsHash, 
        _communicationChannelDetails, 
        _arbitratorAddress, 
        _arbitorCommision
        );

        
        uint256 expectedId = preUniqueId+1;

        
        (
        uint256 _dealId,
        address _dealBuyerWallet,
        address _dealSellerWallet,
        uint256 _dealAmt,
        bytes32 _dealTandC,
        string memory _dealCommunicationChannelDetails,
        address _dealArbitratorAddress,
        EscrowCollection.Decision memory d,
        uint256 _dealArbitrastorCommision,
        uint256 _dealAddedProtocolFee,
        uint256 _dealSellerCount
        ) = escrowCollection.dealDetailsMap(expectedId);
        

        // Checking `DealDetails` struct 
        assertEq(expectedId, _dealId);
        assertEq(fixedBuyAddress, _dealBuyerWallet);
        assertEq(fixedSellAddress, _dealSellerWallet);
        assertEq(_amount, _dealAmt);
        assertEq(_termsAndConditionsHash, _dealTandC);
        assertEq(_communicationChannelDetails, _dealCommunicationChannelDetails);
        assertEq(fixedArbAddress, _dealArbitratorAddress);
        assertEq(_sellerDealCount+1, _dealSellerCount);
        assertEq(_arbitorCommision, _dealArbitrastorCommision);
        assertEq(addedProtocolFee, _dealAddedProtocolFee);

        // Checking `Decision` struct
        assertTrue(d.dealDecision==EscrowCollection.DecisionStatus.DEAL_IN_PROGRESS);
        assertEq(d.award, 0);
        assertEq(d.comments, 0x0000000000000000000000000000000000000000000000000000000000000000);

        // Check balances 
        assertEq(escrowCollection.addressBalance(fixedProtocolAddress), PROTOCOL_BASE_FEE + addedProtocolFee);

    }

    function testAppealToArbitrator() external{

        // Registers a sample deal
        registerSampleDealFixedAddresses(); 

         // Deposit some eth for gas to buyer address
        vm.deal(fixedBuyAddress, someEther);
        
        // Use vm.prank to set the sender of the transaction to fixedSellAddress
        vm.prank(fixedBuyAddress);

        escrowCollection.appealToArbitrator(1);

        (
        uint256 _dealId,
        address _dealBuyerWallet,
        address _dealSellerWallet,
        uint256 _dealAmt,
        bytes32 _dealTandC,
        string memory _dealCommunicationChannelDetails,
        address _dealArbitratorAddress,
        EscrowCollection.Decision memory d,
        uint256 _dealArbitrastorCommision,
        uint256 _dealAddedProtocolFee,
        uint256 _dealSellerCount
        ) = escrowCollection.dealDetailsMap(1);

        assertTrue(d.dealDecision == EscrowCollection.DecisionStatus.PENDING_ARBITRATOR);

    }

    function testRefundWhileDealInProgress() external {

        // Registers a sample deal
        registerSampleDealFixedAddresses(); 

        // Get wallet addresses of parties post registeration of a deal but pre-refund call
        WalletAmountsStruct memory PreCallBalances = getPartiesLatestWithdrawlAmounts();
                
        // Seller deal count pre-refund
        uint256 _sellerDealCount = escrowCollection.sellerDealCount(fixedSellAddress);

        // Added Protocol fee of the sample deal
        uint256 addedProtocolFee = ((PROTOCOL_COMMISION_BPS*_sampleDealAmt)/10000);

        // Deposit some eth for gas to seller address for gas 
        vm.deal(fixedSellAddress, someEther);
        
        // Use vm.prank to set the sender of the transaction to fixedSellAddress
        vm.prank(fixedSellAddress);

        // Initiate refund while DEAL_IN_PROGRESS
        escrowCollection.refund(1);

        (
        uint256 _dealId,
        address _dealBuyerWallet,
        address _dealSellerWallet,
        uint256 _dealAmt,
        bytes32 _dealTandC,
        string memory _dealCommunicationChannelDetails,
        address _dealArbitratorAddress,
        EscrowCollection.Decision memory d,
        uint256 _dealArbitrastorCommision,
        uint256 _dealAddedProtocolFee,
        uint256 _dealSellerCount
        ) = escrowCollection.dealDetailsMap(1);


        // Checking `DealDetails` struct 
        assertEq(1, _dealId);
        assertEq(fixedBuyAddress, _dealBuyerWallet);
        assertEq(fixedSellAddress, _dealSellerWallet);
        assertEq(_sampleDealAmt, _dealAmt);
        assertEq(_sampleTermsAndConditionsHash, _dealTandC);
        assertEq(_samplecommunicationChannelDetails, _dealCommunicationChannelDetails);
        assertEq(fixedArbAddress, _dealArbitratorAddress);
        assertEq(_sellerDealCount, _dealSellerCount);
        assertEq(_sampleArbitorCommision, _dealArbitrastorCommision);
        assertEq(addedProtocolFee, _dealAddedProtocolFee);

        // Checking `Decision` struct
        assertTrue(d.dealDecision==EscrowCollection.DecisionStatus.REFUNDED);
        assertEq(d.award, 0);
        assertEq(d.comments, 0x0000000000000000000000000000000000000000000000000000000000000000);

        // Balances after a refund is made  
        WalletAmountsStruct memory PostCallBalances = getPartiesLatestWithdrawlAmounts(); 

        // Checks Balances
        assertEq(PreCallBalances.fixedArbAddressAmount, PostCallBalances.fixedArbAddressAmount);
        assertEq(PreCallBalances.fixedSellAddressAmount, PostCallBalances.fixedSellAddressAmount);
        assertEq(PostCallBalances.fixedBuyAddressAmount - PreCallBalances.fixedBuyAddressAmount,
        _dealArbitrastorCommision + _dealAmt
        );
        assertEq(PreCallBalances.fixedProtocolAddressAmount, PostCallBalances.fixedProtocolAddressAmount);
        
        
    }

    function testRefundWhileAppealed() external { 

        // Registers a sample deal
        registerSampleDealFixedAddresses(); 
        
        // Get wallet addresses of parties post registeration of a deal but pre-refund call
        WalletAmountsStruct memory PreCallBalances = getPartiesLatestWithdrawlAmounts();

        
        // Deposit some eth for gas to the buyer address for gas 
        vm.deal(fixedBuyAddress, someEther);
        
        // Use vm.prank to set the sender of the transaction to fixedSellAddress
        vm.prank(fixedBuyAddress);

        // Buyer appeals to arbitrator
        escrowCollection.appealToArbitrator(1);

        // Seller deal count pre-refund
        uint256 _sellerDealCount = escrowCollection.sellerDealCount(fixedSellAddress);

        // Added Protocol fee of the sample deal
        uint256 addedProtocolFee = ((PROTOCOL_COMMISION_BPS*_sampleDealAmt)/10000);

        // Deposit some eth for gas to seller address for gas 
        vm.deal(fixedSellAddress, someEther);
        
        // Use vm.prank to set the sender of the transaction to fixedSellAddress
        vm.prank(fixedSellAddress);
        
        // Initiate refund while PENDING_ARBITRATOR
        escrowCollection.refund(1);

        (
        uint256 _dealId,
        address _dealBuyerWallet,
        address _dealSellerWallet,
        uint256 _dealAmt,
        bytes32 _dealTandC,
        string memory _dealCommunicationChannelDetails,
        address _dealArbitratorAddress,
        EscrowCollection.Decision memory d,
        uint256 _dealArbitrastorCommision,
        uint256 _dealAddedProtocolFee,
        uint256 _dealSellerCount
        ) = escrowCollection.dealDetailsMap(1);


        // Checking `DealDetails` struct 
        assertEq(1, _dealId);
        assertEq(fixedBuyAddress, _dealBuyerWallet);
        assertEq(fixedSellAddress, _dealSellerWallet);
        assertEq(_sampleDealAmt, _dealAmt);
        assertEq(_sampleTermsAndConditionsHash, _dealTandC);
        assertEq(_samplecommunicationChannelDetails, _dealCommunicationChannelDetails);
        assertEq(fixedArbAddress, _dealArbitratorAddress);
        assertEq(_sellerDealCount, _dealSellerCount);
        assertEq(_sampleArbitorCommision, _dealArbitrastorCommision);
        assertEq(addedProtocolFee, _dealAddedProtocolFee);

        // Checking `Decision` struct
        assertTrue(d.dealDecision==EscrowCollection.DecisionStatus.REFUNDED);
        assertEq(d.award, 0);
        assertEq(d.comments, 0x0000000000000000000000000000000000000000000000000000000000000000);

        // Balances after a refund is made  
        WalletAmountsStruct memory PostCallBalances = getPartiesLatestWithdrawlAmounts(); 

        // Checks Balances
        assertEq(PostCallBalances.fixedArbAddressAmount - PreCallBalances.fixedArbAddressAmount,
        _dealArbitrastorCommision);
        assertEq(PreCallBalances.fixedSellAddressAmount, PostCallBalances.fixedSellAddressAmount);
        assertEq(PostCallBalances.fixedBuyAddressAmount - PreCallBalances.fixedBuyAddressAmount, 
        _dealAmt);
        assertEq(PreCallBalances.fixedProtocolAddressAmount, PostCallBalances.fixedProtocolAddressAmount);

    }
    
    function testCloseDealWithoutIssueDealInProgress() external{ 
        
        // Registers a sample deal
        registerSampleDealFixedAddresses(); 

         // Deposit some eth for gas to buyer address
        vm.deal(fixedBuyAddress, someEther);
        
        // Use vm.prank to set the sender of the transaction to fixedSellAddress
        vm.prank(fixedBuyAddress);

        // Close deal without issue 
        escrowCollection.closeDealWithoutIssue(1);

        (
        uint256 _dealId,
        address _dealBuyerWallet,
        address _dealSellerWallet,
        uint256 _dealAmt,
        bytes32 _dealTandC,
        string memory _dealCommunicationChannelDetails,
        address _dealArbitratorAddress,
        EscrowCollection.Decision memory d,
        uint256 _dealArbitrastorCommision,
        uint256 _dealAddedProtocolFee,
        uint256 _dealSellerCount
        ) = escrowCollection.dealDetailsMap(1);

        // Buyer gets arbitor commision since arbitor was not involved
        assertEq(escrowCollection.addressBalance(_dealBuyerWallet), _dealArbitrastorCommision); 

        // Seller gets deal amount 
        assertEq(escrowCollection.addressBalance(_dealSellerWallet), _dealAmt); 
        
        // Deal is now CLOSED_WITHOUT_ISSUE
        assertTrue(d.dealDecision==EscrowCollection.DecisionStatus.CLOSED_WITHOUT_ISSUE);
    }

    function testCloseDealWithoutIssuePendingArbitrator () external{ 
        
        // Registers a sample deal
        registerSampleDealFixedAddresses(); 

        // Deposit some eth for gas to buyer address
        vm.deal(fixedBuyAddress, someEther);
        
        // Use vm.prank to set the sender of the transaction to fixedBuyAddress
        vm.prank(fixedBuyAddress);

        // Appeal to arbitrator 
        escrowCollection.appealToArbitrator(1);

        // Use vm.prank to set the sender of the transaction to fixedBuyAddress
        vm.prank(fixedBuyAddress);

        // Close deal without issue 
        escrowCollection.closeDealWithoutIssue(1);

        (
        uint256 _dealId,
        address _dealBuyerWallet,
        address _dealSellerWallet,
        uint256 _dealAmt,
        bytes32 _dealTandC,
        string memory _dealCommunicationChannelDetails,
        address _dealArbitratorAddress,
        EscrowCollection.Decision memory d,
        uint256 _dealArbitrastorCommision,
        uint256 _dealAddedProtocolFee,
        uint256 _dealSellerCount
        ) = escrowCollection.dealDetailsMap(1);

        // Buyer gets arbitor commision since arbitor was not involved
        assertEq(escrowCollection.addressBalance(_dealArbitratorAddress), _dealArbitrastorCommision); 

        // Seller gets deal amount 
        assertEq(escrowCollection.addressBalance(_dealSellerWallet), _dealAmt); 
        
        // Deal is now CLOSED_WITHOUT_ISSUE
        assertTrue(d.dealDecision == EscrowCollection.DecisionStatus.CLOSED_WITHOUT_ISSUE); 
     
    }

    function testCloseDealWithArbitrator() external{ 
        
        // Registers a sample deal
        registerSampleDealFixedAddresses(); 

        // Deposit some eth for gas to buyer address
        vm.deal(fixedBuyAddress, someEther);
        
        // Use vm.prank to set the sender of the transaction to fixedBuyAddress
        vm.prank(fixedBuyAddress);

        // Appeal to arbitrator 
        escrowCollection.appealToArbitrator(1);

        // Use vm.prank to set the sender of the transaction to fixedBuyAddress
        vm.prank(fixedArbAddress);

        // Close deal without issue 
        escrowCollection.closeDealWithArbitrator(1, _sampleAward, _sampleComments);

        (
        uint256 _dealId,
        address _dealBuyerWallet,
        address _dealSellerWallet,
        uint256 _dealAmt,
        bytes32 _dealTandC,
        string memory _dealCommunicationChannelDetails,
        address _dealArbitratorAddress,
        EscrowCollection.Decision memory d,
        uint256 _dealArbitrastorCommision,
        uint256 _dealAddedProtocolFee,
        uint256 _dealSellerCount
        ) = escrowCollection.dealDetailsMap(1);

        // Checking `Decision` struct
        assertTrue(d.dealDecision==EscrowCollection.DecisionStatus.CLOSED_WITH_ARBITRATOR);
        assertEq(d.award, _sampleAward);
        assertEq(d.comments, _sampleComments);

        // Check balances 
        assertEq(escrowCollection.addressBalance(fixedSellAddress), _sampleAward);
        assertEq(escrowCollection.addressBalance(fixedBuyAddress), _dealAmt-_sampleAward);
        assertEq(escrowCollection.addressBalance(fixedArbAddress), _dealArbitrastorCommision);

    }

}
