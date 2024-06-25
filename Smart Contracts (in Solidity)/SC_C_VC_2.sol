// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
import "./SC_VC_Govt.sol";
import "./SC_C_Govt_1.sol";
import "./SC_C_VC_1.sol";
import "./SC_Requirements_Check.sol";
import "./MerkleProofLibrary.sol";

contract SC_C_VC_2
{
    address public addr_SC_VC_Govt;
    SC_VC_Govt instance_SC_VC_Govt;

    address public addr_SC_C_Govt_1;
    SC_C_Govt_1 instance_SC_C_Govt_1;

    address public addr_SC_C_VC_1;
    SC_C_VC_1 instance_SC_C_VC_1;

    address public addr_SC_Requirements_Check;
    SC_Requirements_Check instance_SC_Requirements_Check;

    uint256 public constant timeLimit = 300 seconds;

    constructor(address _addr_SC_VC_Govt, address _addr_SC_C_Govt_1, address _addr_SC_C_VC_1, address _addr_SC_Requirements_Check) 
    {
        addr_SC_VC_Govt = _addr_SC_VC_Govt;
        instance_SC_VC_Govt = SC_VC_Govt(addr_SC_VC_Govt);
        addr_SC_C_Govt_1 = _addr_SC_C_Govt_1;
        instance_SC_C_Govt_1 = SC_C_Govt_1(addr_SC_C_Govt_1);
        addr_SC_C_VC_1 = _addr_SC_C_VC_1;
        instance_SC_C_VC_1 = SC_C_VC_1(addr_SC_C_VC_1);
        addr_SC_Requirements_Check = _addr_SC_Requirements_Check;
        instance_SC_Requirements_Check = SC_Requirements_Check(addr_SC_Requirements_Check);
    }

    /**
    Caller: Citizen
    When: VC has not locked money by calling lockMoneyByVC() within timeout after sending tokenID.
          So, citizen can exit the protocol and initiates a new one.
    Previous Function: sendTokenID() by C (Ideal Case - lockMoneyByVC() by VC)
    **/
    function exit1ByC() external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        
        uint256 _latestProtocolNo;
        bool _isProtocolRunning;
        (_latestProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(msg.sender);
        require(_isProtocolRunning == true, "RR34");
        
        uint256 timestamp_send_tokenID;
        uint256 timestamp_lock_money_by_VC;
        uint256 tokenID;
        (tokenID, , timestamp_send_tokenID, timestamp_lock_money_by_VC, , , , , , , , , , , , , , , , , , , , , ) = instance_SC_C_VC_1.getProtocolDetails(_latestProtocolNo);
        
        require(_tokenID == tokenID, "RR36");
        require(timestamp_send_tokenID != 0,"RR39");
        require(timestamp_lock_money_by_VC == 0 && (block.timestamp - timestamp_send_tokenID) > timeLimit, "RR66");
        
        instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);
    }

    
    /**
    Caller: Vaccination Center
    When: If Citizen has not locked money by calling lockMoneyByC() within timeout after VC's locking,
          the VC can exit the protocol and unlock it's locked money from SC.
    Previous Function: lockMoneyByVC() by VC (Ideal Case - lockMoneyByC() by C)
    **/
    function exit2ByVC(address _cAddr) external
    {
        instance_SC_Requirements_Check.checkForRegisteredVC(msg.sender);
        
        uint256 _latestProtocolNo;
        bool _isProtocolRunning;
        (_latestProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(_cAddr);
        require(_isProtocolRunning == true, "RR34");
        
        uint256 _vcID = instance_SC_VC_Govt.getvcID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);
        
        uint256 tokenID;
        uint256 vcID;
        uint256 timestamp_lock_money_by_VC;
        uint256 timestamp_lock_money_by_C;
        (tokenID, vcID, , timestamp_lock_money_by_VC, timestamp_lock_money_by_C, , , , , , , , , , , , , , , , , , , , ) = instance_SC_C_VC_1.getProtocolDetails(_latestProtocolNo);
        
        require(_vcID == vcID, "RR65");
        require(_tokenID == tokenID, "RR36");
        require(timestamp_lock_money_by_VC != 0, "RR41");
        require(timestamp_lock_money_by_C == 0 && (block.timestamp - timestamp_lock_money_by_VC) > timeLimit, "RR67");
        
        instance_SC_C_VC_1.transferMoneyToVC(msg.sender,_latestProtocolNo);
        instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);
    }

    /**
    Caller: Citizen
    When: If the VC didn't commit the MT_Proof within timeout, citizen can exit the protocol 
          and start a fresh one. Here, the system penalizes the VC by deducting it's locked money 
          and credits the same to the citizen's account.
    Previous Function: lockMoneyByC() by C (Ideal Case - commitMTProof() by VC)
    **/
    function exit3ByC() external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        
        uint256 _latestProtocolNo;
        bool _isProtocolRunning;
        (_latestProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(msg.sender);
        require(_isProtocolRunning == true, "RR34");
        
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        
        uint256 timestamp_lock_money_by_C;
        uint256 tokenID;
        uint256 timestamp_commit_MT_Proof;
        (tokenID, , , , timestamp_lock_money_by_C, , , timestamp_commit_MT_Proof, , , , , , , , , , , , , , , , , ) = instance_SC_C_VC_1.getProtocolDetails(_latestProtocolNo);        
        
        require(timestamp_lock_money_by_C != 0,"RR45");
        require(_tokenID == tokenID, "RR36");
        require(timestamp_commit_MT_Proof == 0 && (block.timestamp - timestamp_lock_money_by_C) > timeLimit, "RR66");
        
        instance_SC_C_VC_1.penalizeVCAndTransferMoneyToC(msg.sender, _latestProtocolNo);
        instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);
        
    }


    /**
    Caller: Vaccination Center
    When: If the citizen doesn't provide its consent1(true/false) within timeout, 
          the VC can call this function to abort the protocol. In this case, the system penalizes 
          the citizen by deducting it's locked money and credits the same to the VC's account.
    Previous Function: commitMTProof() by VC (Ideal Case: provideConsent1() by C)
    **/
    function exit4ByVC(address _cAddr) external
    {
        instance_SC_Requirements_Check.checkForRegisteredVC(msg.sender);
        
        uint256 _latestProtocolNo;
        bool _isProtocolRunning;
        (_latestProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(_cAddr);
        require(_isProtocolRunning == true, "RR34");

        uint256 _vcID = instance_SC_VC_Govt.getvcID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);

        uint256 vcID;
        uint256 tokenID;
        uint256 timestamp_commit_MT_Proof;
        uint256 timestamp_consent1;
        (tokenID, vcID, , , , , ,timestamp_commit_MT_Proof, ,timestamp_consent1, , , , , , , , , , , , , , , ) = instance_SC_C_VC_1.getProtocolDetails(_latestProtocolNo);

        require(_vcID == vcID, "RR65");
        require(_tokenID == tokenID, "RR36");
        require(timestamp_commit_MT_Proof != 0, "RR48");
        require(timestamp_consent1 == 0 && (block.timestamp - timestamp_commit_MT_Proof) > timeLimit, "RR67");
        
        instance_SC_C_VC_1.penalizeCAndTransferMoneyToVC(msg.sender, _latestProtocolNo);
        instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);
        
    }
    
    /**
    Caller: Citizen
    When: If the VC didn't commit the vial ID within timeout even after giving consent 1, citizen can exit the protocol 
          and start a fresh one. Here, the system penalizes the VC by deducting it's locked money 
          and credits the same to the citizen's account.
    Previous Function: provideConsent1() by C (Ideal Case - commitVialID() by VC)
    **/
    function exit5ByC() external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);

        uint256 _latestProtocolNo;
        bool _isProtocolRunning;
        (_latestProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(msg.sender);
        require(_isProtocolRunning == true, "RR34");
        
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        
        uint256 tokenID;
        uint256 timestamp_consent1;
        uint256 timestamp_commit_vialID;
        (tokenID, , , , , , , , ,timestamp_consent1, , timestamp_commit_vialID, , , , , , , , , , , , , ) = instance_SC_C_VC_1.getProtocolDetails(_latestProtocolNo);

        require( _tokenID == tokenID, "RR36");
        require(timestamp_consent1 != 0, "RR50");
        require(timestamp_commit_vialID == 0 && (block.timestamp - timestamp_consent1) > timeLimit, "RR66");
        
        instance_SC_C_VC_1.penalizeVCAndTransferMoneyToC(msg.sender, _latestProtocolNo);
        instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);
    }

    /**
    Caller: Vaccination Center
    When: If the citizen didn't provide it's consent2 within timeout after vial ID commitment, VC can exit the protocol.
          Here, the system penalizes the citizen by deducting it's locked money and credits the same to the VC's account.
    Previous Function: commitVialID() by VC (Ideal Case: provideConsent2() by C)
    **/
    function exit6ByVC(address _cAddr) external
    {
        instance_SC_Requirements_Check.checkForRegisteredVC(msg.sender);
        
        uint256 _latestProtocolNo;
        bool _isProtocolRunning;
        (_latestProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(_cAddr);
        require(_isProtocolRunning == true, "RR34");

        uint256 _vcID = instance_SC_VC_Govt.getvcID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);

        uint256 vcID;
        uint256 tokenID;
        bytes32 vialHash;
        uint256 timestamp_commit_vialID;
        uint256 timestamp_consent2;
        (tokenID,vcID, , , , , , , , , vialHash, timestamp_commit_vialID, , timestamp_consent2, , , , , , , , , , , ) = instance_SC_C_VC_1.getProtocolDetails(_latestProtocolNo);

        require(_vcID == vcID, "RR65");
        require(_tokenID == tokenID, "RR36");
        require(timestamp_commit_vialID != 0, "RR53");
        require(timestamp_consent2 == 0 && (block.timestamp - timestamp_commit_vialID) > timeLimit, "RR67");
        
        instance_SC_C_VC_1.penalizeCAndTransferMoneyToVC(msg.sender, _latestProtocolNo);
        instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);

        instance_SC_VC_Govt.setVialState(vialHash, 0); //Mark vaccine vial as "UNUSED"
    }

    /**
    Caller: Vaccination Center
    When: If the citizen didn't provide it's consent3 within timeout after consent2, VC can exit the protocol.
          Here, the system penalizes the citizen by deducting it's locked money and credits the same to the VC's account.
    Previous Function: provideConsent2() by C (Ideal Case: provideConsent3() by C)
    **/
    function exit7ByVC(address _cAddr) external 
    {
        instance_SC_Requirements_Check.checkForRegisteredVC(msg.sender);
        
        uint256 _latestProtocolNo;
        bool _isProtocolRunning;
        (_latestProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(_cAddr);
        require(_isProtocolRunning == true, "RR34");

        uint256 _vcID = instance_SC_VC_Govt.getvcID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);

        uint256 vcID;
        uint256 tokenID;
        bytes32 vialHash;
        uint256 timestamp_consent2;
        uint256 timestamp_consent3;
        (tokenID,vcID, , , , , , , , , vialHash, , , timestamp_consent2, , timestamp_consent3, , , , , , , , , ) = instance_SC_C_VC_1.getProtocolDetails(_latestProtocolNo);
        
        require(_vcID == vcID, "RR65");
        require(_tokenID == tokenID, "RR36");
        require(timestamp_consent2 != 0, "RR55");
        require(timestamp_consent3 == 0 && (block.timestamp - timestamp_consent2) > timeLimit, "RR67");
        
        instance_SC_C_VC_1.penalizeCAndTransferMoneyToVC(msg.sender, _latestProtocolNo);
        instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);
        
        instance_SC_VC_Govt.setVialState(vialHash, 0); //Mark vaccine vial as "UNUSED"
    }

    /**
    Caller: Vaccination Center
    When: If the citizen provides 'false' consent3 within timeout after consent2, VC needs to reveal Proof. The protocol identifies the 
          faulty party, penalizes and then exits.
    Previous Function: provideConsent3() by C AND consent3 is FALSE.
    **/
    function revealProof(address _cAddr, bytes32[] memory _hashes, string memory _vialID) external
    {
        /**
            1. hashVal: hashes of log(n) internal nodes of Merkle Tree; isLeftChild: true, if the given vial ID node is left child of it's immediate paernt node.
        */
        instance_SC_Requirements_Check.checkForRegisteredVC(msg.sender);

        uint256 _latestProtocolNo;
        bool _isProtocolRunning;
        (_latestProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(_cAddr);
        require(_isProtocolRunning == true, "RR34");

        uint256 _vcID = instance_SC_VC_Govt.getvcID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);

        uint256 vcID;
        uint256 tokenID;
        bool consent3;
        uint256 timestamp_consent3;
        uint256 timestamp_proof_submission;
        uint256 stockID;
        bytes32 commit_MT_Proof;
        bytes32 commit_vialID;
        (tokenID, vcID, , , , stockID, commit_MT_Proof, , , , commit_vialID, , , , consent3, timestamp_consent3, , timestamp_proof_submission, , , , , , , ) = instance_SC_C_VC_1.getProtocolDetails(_latestProtocolNo);

        require(_vcID == vcID, "RR43");
        require(_tokenID == tokenID, "RR36");
       
        require(timestamp_consent3 != 0, "RR58");
        require(consent3 == false, "RR59");
        require(timestamp_proof_submission == 0, "RR60");
        require((block.timestamp - timestamp_consent3) <= timeLimit, "RR8");

        instance_SC_C_VC_1.submitProof(_hashes, _latestProtocolNo);
        instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);
        
        if( commit_MT_Proof != keccak256(abi.encodePacked(_hashes)) || commit_vialID != keccak256(abi.encodePacked(_vialID)) ) //VC is malicious.
        {
            //Penalize VC, unlock and trasfer money..
            instance_SC_C_VC_1.penalizeVCAndTransferMoneyToC(_cAddr, _latestProtocolNo);
            instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);
            instance_SC_VC_Govt.setVialState(commit_vialID, 0); //Mark vaccine vial as "UNUSED"
            return;
        }

        bytes32 _MR_Root;
        (,,,_MR_Root) = instance_SC_VC_Govt.getStockInfo(stockID);
        bytes32 leaf = keccak256(abi.encodePacked(_vialID));
        if( MerkleProof.verify(_hashes, _MR_Root, leaf) != true ) //VC is malicious.
        {
            //Penalize VC, unlock and trasfer money..  
            instance_SC_C_VC_1.penalizeVCAndTransferMoneyToC(_cAddr, _latestProtocolNo);
            instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);
            instance_SC_VC_Govt.setVialState(commit_vialID, 0); //Mark vaccine vial as "UNUSED" 
            return;
        }
        
        //The citizen is malicious and made false claim intentionally. 
        //Penalize Citizen, unlock and trasfer money..
        instance_SC_C_VC_1.penalizeCAndTransferMoneyToVC(msg.sender, _latestProtocolNo);
        instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);
        instance_SC_VC_Govt.setVialState(commit_vialID, 0); //Mark vaccine vial as "UNUSED" 
    }

    /**
    Caller: Citizen
    When: If consent 3 is false and VC does not reveal proof to the smart contract within timeout,
          citizen can exit the protocol. Here, the system penalizes the VC by deducting it's locked money 
          and credits the same to the citizen's account.
    Previous Function: provideConsent3() by C AND consent3 is FALSE (Ideal Case: revealProof() by VC)
    **/
    function exit8ByC() external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);

        uint256 _latestProtocolNo;
        bool _isProtocolRunning;
        (_latestProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(msg.sender);
        require(_isProtocolRunning == true, "RR34");

        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        
        uint256 tokenID;
        bytes32 vialHash;
        bool consent3;
        uint256 timestamp_consent3;
        uint256 timestamp_proof_submission;
        (tokenID, , , , , , , , , , vialHash, , , , consent3, timestamp_consent3, , timestamp_proof_submission, , , , , , , ) = instance_SC_C_VC_1.getProtocolDetails(_latestProtocolNo);
        
        require( _tokenID == tokenID, "RR36");
        require(consent3 == false, "RR59");
        require(timestamp_consent3 != 0, "RR58");
        require(timestamp_proof_submission == 0 && (block.timestamp - timestamp_consent3) > timeLimit, "RR66");
        
        instance_SC_C_VC_1.penalizeVCAndTransferMoneyToC(msg.sender, _latestProtocolNo);
        instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);

        instance_SC_VC_Govt.setVialState(vialHash, 0); //Mark vaccine vial as "UNUSED" 
    }

    /**
    If consent 3 is TRUE, and the VC fails to register the vaccination timestamp on the smart contract within the specified timeout period, 
    there could be multiple reasons for this:

    (i) The VC may not have administered the vaccine to the citizen.
    (ii) Even if the citizen received the vaccine, the VC might be unable to register the vaccination timestamp within the specified timeout.
    (iii) Due to the rivalry equation, there is a possibility that the VC intentionally resisting the citizen to obtain the vaccine passport. 
    However, this scenario is less likely since, in that case, the VC would not have locked money at the initial stage of the protocol.

    It remains uncertain whether the vaccine was genuinely administered or not; legal assistance is required to resolve the dispute.

    To understand the VC's motives for such a malicious attempt, it is crucial to consider that the VC's financial interests are at risk, 
    and the service charge has not been received yet. It is more plausible that the VC fabricates a fake timestamp of vaccination to gain 
    financial benefits, despite not genuinely administering the vaccine.

    Therefore, we can not terminate the protocol at this point, essentially imposing restrictions on the citizen from reapplying for fresh vaccination.
    Additionally, the status of the vaccine vial remains neither marked as "SPENT" nor "UNUSED." Only legal intervention can address and resolve this issue.
    
    Similarly, if the citizen denies the vaccination even after VC registers the timestamp on SC, this cannot be resolved without legal intervention. 
    a negative acknowledgment from the citizen creates a conflict, which can be resolved with legal aid. Until the resolution (or detection of a faulty party),
    citizens cannot re-apply for vaccination, and their locked amount cannot be unlocked.
    */

    /**
    Caller: Vaccination Center
    When: Once the citizen sends a positive acknowledgment for vaccination within timeLimit, VC gets its locked 
          amount and service charge automatically. In case the citizen doesn't provide any acknowledgment within the 
          specified time limit, VC is allowed to unlock its money and collect the service charge by invoking this function.
          Only. Basically, in that case we are assuming the vaccine was injected correctly. So, make the vial as "SPENT" 
    Previous Function: acknowledgeVaccination by Citizen
    **/
    function getPayment(address _cAddr) external
    {
        instance_SC_Requirements_Check.checkForRegisteredVC(msg.sender);

        uint256 _latestProtocolNo;
        bool _isProtocolRunning;
        (_latestProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(_cAddr);
        require(_isProtocolRunning == true, "RR34");

        uint256 _vcID = instance_SC_VC_Govt.getvcID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);

        uint256 vcID;
        uint256 tokenID;
        bytes32 vialHash;
        uint256 timestamp_vaccination;
        uint256 timestamp_acknowledgement ;
        
        (tokenID, vcID, , , , , , , , , vialHash, , , , , , , , timestamp_vaccination, , timestamp_acknowledgement, , , , ) = instance_SC_C_VC_1.getProtocolDetails(_latestProtocolNo);

        require(_vcID == vcID, "RR43");
        require(_tokenID == tokenID, "RR36");
        require(timestamp_vaccination != 0, "RR90");
        require(timestamp_acknowledgement == 0, "RR91");
        require((block.timestamp - timestamp_vaccination) > timeLimit, "RR92");

        //Penalize citizen, transfer Locked Money & Service Charge to VC..
        instance_SC_C_VC_1.penalizeCAndTransferMoneyToVC(msg.sender, _latestProtocolNo);
        instance_SC_VC_Govt.payServiceCharge(msg.sender);

        instance_SC_VC_Govt.setVialState(vialHash, 1); //Mark vaccine vial as "SPENT"
        instance_SC_C_Govt_1.setVaccinationStatus(tokenID); //Change the citizen's vaccination status 
        
        instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);
    }

    
    
    /*
    ********************************************************
    NOT REQUIRED NOW!!
    ********************************************************
    Caller: Citizen
    When: If consent 3 is true and VC does not inject the vaccine and upload cID to the smart contract within timeout,
          citizen can exit the protocol. Here, the system penalizes the VC by deducting it's locked money 
          and credits the same to the citizen's account.
    Previous Function: provideConsent3() by C AND consent3 is TRUE (IDEAL Case: uploadVPInfoAndGetPayment() by VC)
    
    function exit10ByC() external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);

        uint256 _latestProtocolNo;
        bool _isProtocolRunning;
        (_latestProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(msg.sender);
        require(_isProtocolRunning == true, "RR34");

        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        
        uint256 tokenID;
        bool consent3;
        uint256 timestamp_consent3;
        (tokenID, , , , , , , , , , , , , , consent3, timestamp_consent3, , , , , , ) = instance_SC_C_VC_1.getProtocolDetails(_latestProtocolNo);
        
        require(_tokenID == tokenID, "RR36");
        require(consent3 == true, "RR64");
        require(timestamp_consent3 != 0, "RR58");

        uint256 timestamp_create_vp;
        ( , , , timestamp_create_vp) = instance_SC_C_VC_1.getVPDetails(tokenID);
        require(timestamp_create_vp == 0 && (block.timestamp - timestamp_consent3) > timeLimit, "RR66");
        
        instance_SC_C_VC_1.penalizeVCAndTransferMoneyToC(msg.sender, _latestProtocolNo);
        instance_SC_C_VC_1.abortProtocol(_latestProtocolNo);
    }
    **/
}