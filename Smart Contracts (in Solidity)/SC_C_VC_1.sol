// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
import "./SC_VC_Govt.sol";
import "./SC_C_Govt_1.sol";
import "./SC_Requirements_Check.sol";
//import "./MerkleProofLibrary.sol";

contract SC_C_VC_1
{
    
    address addr_SC_VC_Govt;
    SC_VC_Govt instance_SC_VC_Govt;

    address addr_SC_C_Govt_1;
    SC_C_Govt_1 instance_SC_C_Govt_1;

    address addr_SC_Requirements_Check;
    SC_Requirements_Check instance_SC_Requirements_Check;

    struct VaccineInjectingProtocol
    {
        uint256 tokenID; //Populated by C
        uint256 vcID; //Populated by C
        uint256 timestamp_send_tokenID; //Populated by C
        uint256 timestamp_lock_money_by_VC; //Populated by VC
        uint256 timestamp_lock_money_by_C; //Populated by C
        uint256 stockID; //Populated by VC
        bytes32 commit_MT_Proof; //Populated by VC
        uint256 timestamp_commit_MT_Proof; //Populated by VC
        bool consent1; //Populated by C
        uint256 timestamp_consent1; //Populated by C
        bytes32 commit_vialID; //Populated by VC..commit_vialID = vialIDHash
        uint256 timestamp_commit_vialID; //Populated by VC
        bool consent2; //Populated by C
        uint256 timestamp_consent2; //Populated by C
        bool consent3; //Populated by C
        uint256 timestamp_consent3; //Populated by C
        bytes32[] proof_submitted_by_VC; //Populated by VC
        uint256 timestamp_proof_submission; //Populated by VC
        uint256 timestamp_vaccination; //Populated by VC
        bool acknowledge_vaccination; //Populated by C
        uint256 timestamp_acknowledgement; //Populated by C
        uint256 money_received_by_VC;
        uint256 timestamp_receive_money_by_VC;
        uint256 money_received_by_C;
        uint256 timestamp_receive_money_by_C;
    }

    //mapping(uint256 => address) protocolInitiatedBy; //Maps: protocol number -> citizen Addr (who initiates the protocol)
    mapping(address => uint256) latestVaccineInjectingProtocolNumber; //Maps: citizen Addr -> Latest Vaccine Injecting Protocol No
    mapping(uint256 => bool) injectingProtocolCurrentlyRuns; //Maps: Protocol Number -> is currently running (boolean)
    mapping(uint256 => bool) protocolAborted; //Maps: Protocol Number -> is protocol aborted (boolean)
    mapping(uint256 => VaccineInjectingProtocol) vaccineInjectingProtocol; //Maps: protocol No -> Protocol Details 
    
    uint256 public injectingProtocolNumberGenerator = 0;
    uint256 public constant timeLimit = 300 seconds;
    uint256 public constant lockingAmount = 500 wei;
    
    constructor(address _addr_SC_VC_Govt, address _addr_SC_C_Govt_1, address _addr_SC_Requirements_check) 
    {
        addr_SC_VC_Govt = _addr_SC_VC_Govt;
        instance_SC_VC_Govt = SC_VC_Govt(addr_SC_VC_Govt);
        addr_SC_C_Govt_1 = _addr_SC_C_Govt_1;
        instance_SC_C_Govt_1 = SC_C_Govt_1(addr_SC_C_Govt_1);
        addr_SC_Requirements_Check = _addr_SC_Requirements_check;
        instance_SC_Requirements_Check = SC_Requirements_Check(addr_SC_Requirements_Check);
    }

    /**
    Caller: Citizen (holding a valid TokenID and not yet vaccinated)
    When: To initiate Vaccine Injecting Process.
    Previous Function: NA
    Change function name to beginProtocol() as mentioned in the paper.
    **/
    function beginProtocol(uint256 _vcID) external  
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        instance_SC_Requirements_Check.checkForCitizenNotYetVaccinated(_tokenID);
        instance_SC_Requirements_Check.checkForRegisteredVC(_vcID);
        instance_SC_Requirements_Check.checkForVaccineStock(_vcID);
        
        uint256 _latestProtocolNo = latestVaccineInjectingProtocolNumber[msg.sender];
        require(injectingProtocolCurrentlyRuns[_latestProtocolNo] == false, "RR33");
        
        injectingProtocolNumberGenerator += 1;
        _latestProtocolNo = injectingProtocolNumberGenerator;
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];
        x.tokenID = _tokenID;
        x.vcID = _vcID;
        x.timestamp_send_tokenID = block.timestamp;
        vaccineInjectingProtocol[_latestProtocolNo] = x;
        latestVaccineInjectingProtocolNumber[msg.sender] = _latestProtocolNo;
        injectingProtocolCurrentlyRuns[_latestProtocolNo] = true;
        //protocolInitiatedBy[_latestProtocolNo] = msg.sender;
    }

    /**
    Caller: Vaccination Center (holding a valid vcID)
    When: Once citizen initiates the vaccine injecting protocol by sending tokenID, 
          the vaccination center calls the function to lock money on SC.
    Previous Function: sendTokenID() by Citizen
    **/
    function lockMoneyByVC(address _cAddr) external payable
    {
        instance_SC_Requirements_Check.checkForRegisteredVC(msg.sender);
        uint256 _latestProtocolNo = latestVaccineInjectingProtocolNumber[_cAddr];
        require(injectingProtocolCurrentlyRuns[_latestProtocolNo] == true, "RR34");
        
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];
        
        uint256 _vcID = instance_SC_VC_Govt.getvcID(msg.sender); 
        require(_vcID == x.vcID, "RR35"); //Autheticating VC
        instance_SC_Requirements_Check.checkForVaccineStock(_vcID);
        
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);
        require(_tokenID == x.tokenID, "RR36"); //Authenticating Citizen
        instance_SC_Requirements_Check.checkForCitizenNotYetVaccinated(_tokenID);
        
        require(msg.value == lockingAmount, "RR38");
        require(x.timestamp_send_tokenID != 0, "RR39");
        require(x.timestamp_lock_money_by_VC == 0, "RR40");
        require((block.timestamp - x.timestamp_send_tokenID) <= timeLimit, "RR8");

        x.timestamp_lock_money_by_VC = block.timestamp;
        vaccineInjectingProtocol[_latestProtocolNo] = x;
    }

    /**
    Caller: Citizen
    When: Once VC locked money by calling lockMoneyByVC(), citizen also locks money by calling this function.
    Previous Function: lockMoneyByVC() by VC
    **/
    function lockMoneyByC(uint256 _vcID) external payable 
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        uint256 _latestProtocolNo = latestVaccineInjectingProtocolNumber[msg.sender];
        require(injectingProtocolCurrentlyRuns[_latestProtocolNo] == true, "RR34");
        
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];

        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        require(_tokenID == x.tokenID, "RR36"); //Authenticating Citizen
        instance_SC_Requirements_Check.checkForCitizenNotYetVaccinated(_tokenID);

        require(_vcID == x.vcID, "RR37"); //Authenticating VC
        instance_SC_Requirements_Check.checkForVaccineStock(_vcID);

        require(msg.value == lockingAmount, "RR38");
        require(x.timestamp_lock_money_by_VC != 0, "RR41");
        require(x.timestamp_lock_money_by_C == 0, "RR42");
        require((block.timestamp - x.timestamp_lock_money_by_VC) <= timeLimit, "RR8");

        x.timestamp_lock_money_by_C = block.timestamp;
        vaccineInjectingProtocol[_latestProtocolNo] = x;
    }

    /**
    Caller: Vaccination Center
    When: After the citizen locked money, VC needs to commit the MT Proof.
    Previous Function: lockMoneyByC() by Citizen
    **/
    function commitMTProof(address _cAddr, bytes32 _commit_MT_Proof) external
    {
        instance_SC_Requirements_Check.checkForRegisteredVC(msg.sender);
        uint256 _latestProtocolNo = latestVaccineInjectingProtocolNumber[_cAddr];
        require(injectingProtocolCurrentlyRuns[_latestProtocolNo] == true, "RR34");
        
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];
        
        uint256 _vcID = instance_SC_VC_Govt.getvcID(msg.sender);
        uint256 _currentStockID;
        uint256 _remainingVials;
        (,_currentStockID,_remainingVials,) = instance_SC_VC_Govt.getVC(_vcID);
        require(_vcID == x.vcID, "RR43"); //Authenticating VC
        require(_remainingVials != 0, "RR44");
        
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);
        require(_tokenID == x.tokenID, "RR36"); //Authenticating Citizen
        instance_SC_Requirements_Check.checkForCitizenNotYetVaccinated(_tokenID);

        require(x.timestamp_lock_money_by_C != 0, "RR45");
        require(x.timestamp_commit_MT_Proof == 0, "RR46");
        require((block.timestamp - x.timestamp_lock_money_by_C) <= timeLimit, "RR8");

        x.stockID = _currentStockID;
        x.commit_MT_Proof = _commit_MT_Proof;
        x.timestamp_commit_MT_Proof = block.timestamp;
        vaccineInjectingProtocol[_latestProtocolNo] = x;
    }

    /**
    Caller: Citizen
    When: After VC sends the MT_Proof to Citizen,
          Citizen checks if it matches with the commitment made by VC and accordingly provides its consent.
          If citizen isn't agreed with the commitment the protocol gets aborted.
    Previous Function: commitMTProof() by VC
    **/
    function provideConsent1(uint256 _vcID, bool _consent1) external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        uint256 _latestProtocolNo = latestVaccineInjectingProtocolNumber[msg.sender];
        require(injectingProtocolCurrentlyRuns[_latestProtocolNo] == true, "RR34");
        
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];

        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        require(_tokenID == x.tokenID, "RR36");
        instance_SC_Requirements_Check.checkForCitizenNotYetVaccinated(_tokenID);

        require(_vcID == x.vcID, "RR37");
        uint256 _currentStockID;
        uint256 _remainingVials;
        (,_currentStockID,_remainingVials,) = instance_SC_VC_Govt.getVC(_vcID);
        require(_remainingVials != 0, "RR44");
        require(x.stockID == _currentStockID, "RR47");

        require(x.timestamp_commit_MT_Proof != 0, "RR48");
        require(x.timestamp_consent1 == 0, "RR49");
        require((block.timestamp - x.timestamp_commit_MT_Proof) <= timeLimit, "RR8");

        x.consent1 = _consent1;
        x.timestamp_consent1 = block.timestamp;

        if(_consent1 == false)
        {
            //Abort the current protocol, unlock and trasfer money to the parties..
            injectingProtocolCurrentlyRuns[_latestProtocolNo] = false;
            protocolAborted[_latestProtocolNo] = true;
            payable(msg.sender).transfer(lockingAmount);
            payable(instance_SC_VC_Govt.getvcAddr(_vcID)).transfer(lockingAmount);
            x.money_received_by_C = lockingAmount;
            x.money_received_by_VC = lockingAmount;
            x.timestamp_receive_money_by_C = block.timestamp;
            x.timestamp_receive_money_by_VC = block.timestamp;
        }

        vaccineInjectingProtocol[_latestProtocolNo] = x;
    }

    
    /**
    Caller: Vaccination Center
    When: Receiving positive consent1 from citizen, VC will commit the vaccine vial ID.
    Previous Function: provideConsent1() by Citizen
    **/
    function commitVialID(address _cAddr, bytes32 _commit_vID) external 
    {
        instance_SC_Requirements_Check.checkForRegisteredVC(msg.sender);
        uint256 _latestProtocolNo = latestVaccineInjectingProtocolNumber[_cAddr];
        require(injectingProtocolCurrentlyRuns[_latestProtocolNo] == true, "RR34");
        
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];
        
        uint256 _vcID = instance_SC_VC_Govt.getvcID(msg.sender);
        require(_vcID == x.vcID, "RR43"); //Authenticating VC
        uint256 _currentStockID;
        uint256 _remainingVials;
        (,_currentStockID,_remainingVials,) = instance_SC_VC_Govt.getVC(_vcID);
        
        require(_remainingVials != 0, "RR44");
        require(x.stockID == _currentStockID, "RR47");
        instance_SC_Requirements_Check.checkForUnusedVaccineVial(_commit_vID);

        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);
        require(_tokenID == x.tokenID, "RR36"); //Authenticating Citizen
        instance_SC_Requirements_Check.checkForCitizenNotYetVaccinated(_tokenID);
        
        require(x.timestamp_consent1 != 0, "RR50");
        require(x.consent1 == true, "RR51");
        require(x.timestamp_commit_vialID == 0, "RR52");
        require((block.timestamp - x.timestamp_consent1) <= timeLimit, "RR8");

        x.commit_vialID = _commit_vID;
        x.timestamp_commit_vialID = block.timestamp;
        vaccineInjectingProtocol[_latestProtocolNo] = x;

        instance_SC_VC_Govt.setVialState(_commit_vID, 2); //Mark vaccine vial as "UNDER_PROTOCOL_EXECUTION"
    }

    /**
    Caller: Citizen
    When: Receiving vaccine vial, citizen will check if the vialID matches with the commitment made by VC.
    Previous Function: commitVialID() by VC
    **/
    function provideConsent2(uint256 _vcID, bool _consent2) external  
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        uint256 _latestProtocolNo = latestVaccineInjectingProtocolNumber[msg.sender];
        require(injectingProtocolCurrentlyRuns[_latestProtocolNo] == true, "RR34");
        
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];

        require(_vcID == x.vcID, "RR37"); //Authenticating VC

        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        require(_tokenID == x.tokenID, "RR36"); //Authenticating Citizen
        instance_SC_Requirements_Check.checkForCitizenNotYetVaccinated(_tokenID);

        uint256 _currentStockID;
        uint256 _remainingVials;
        (,_currentStockID,_remainingVials,) = instance_SC_VC_Govt.getVC(_vcID);
        require(_remainingVials != 0, "RR44");
        require(x.stockID == _currentStockID, "RR47");
        instance_SC_Requirements_Check.checkForUnderProtocolExecVaccineVial(x.commit_vialID);

        require(x.timestamp_commit_vialID != 0, "RR53");
        require(x.timestamp_consent2 == 0, "RR54");
        require((block.timestamp - x.timestamp_commit_vialID) <= timeLimit, "RR8");

        x.consent2 = _consent2;
        x.timestamp_consent2 = block.timestamp;

        if(_consent2 == false)
        {
            //Abort the current protocol, unlock and trasfer money to the parties..
            injectingProtocolCurrentlyRuns[_latestProtocolNo] = false;
            protocolAborted[_latestProtocolNo] = true;
            payable(msg.sender).transfer(lockingAmount);
            payable(instance_SC_VC_Govt.getvcAddr(_vcID)).transfer(lockingAmount);
            x.money_received_by_C = lockingAmount;
            x.money_received_by_VC = lockingAmount;
            x.timestamp_receive_money_by_C = block.timestamp;
            x.timestamp_receive_money_by_VC = block.timestamp;
        }

        vaccineInjectingProtocol[_latestProtocolNo] = x;
    }

    /**
    Caller: Citizen
    When: If the commitment matches with the vial ID, the citizen will check if the given vial
          is a authentic one - i.e. the vial belongs to the vaccine set supplied by the Govt.
    Previous Function: provideConsent2 by Citizen
    **/
    function provideConsent3(uint256 _vcID, bool _consent3) external  
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        uint256 _latestProtocolNo = latestVaccineInjectingProtocolNumber[msg.sender];
        require(injectingProtocolCurrentlyRuns[_latestProtocolNo] == true, "RR34");
        
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];

        require(_vcID == x.vcID, "RR37"); //Authenticating VC

        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        require(_tokenID == x.tokenID, "RR36"); //Authenticating Citizen
        instance_SC_Requirements_Check.checkForCitizenNotYetVaccinated(_tokenID);

        uint256 _currentStockID;
        uint256 _remainingVials;
        (,_currentStockID,_remainingVials,) = instance_SC_VC_Govt.getVC(_vcID);
        require(_remainingVials != 0, "RR44");
        require(x.stockID == _currentStockID, "RR47");
        instance_SC_Requirements_Check.checkForUnderProtocolExecVaccineVial(x.commit_vialID);

        require(x.timestamp_consent2 != 0, "RR55");
        require(x.consent2 == true, "RR56");
        require(x.timestamp_consent3 == 0, "RR57");
        require((block.timestamp - x.timestamp_consent2) <= timeLimit, "RR8");

        x.consent3 = _consent3;
        x.timestamp_consent3 = block.timestamp;
        
        vaccineInjectingProtocol[_latestProtocolNo] = x;
    }

    /**
    Caller: Vaccination Center
    When: Once the citizen provides consent3, VC will begin injecting the vaccine and then register the timestamp
          of vaccination on the BC by calling this function.   
    Previous Function: provideConsent3 by Citizen
    **/
    function registerVaccinationTimestamp(address _cAddr) external
    {
        instance_SC_Requirements_Check.checkForRegisteredVC(msg.sender);
        uint256 _latestProtocolNo = latestVaccineInjectingProtocolNumber[_cAddr];
        require(injectingProtocolCurrentlyRuns[_latestProtocolNo] == true, "RR34");
        
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];
        
        uint256 _vcID = instance_SC_VC_Govt.getvcID(msg.sender);
        require(_vcID == x.vcID, "RR43"); //Authenticating VC

        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);
        require(_tokenID == x.tokenID, "RR36"); //Authenticating Citizen
        instance_SC_Requirements_Check.checkForCitizenNotYetVaccinated(_tokenID);

        require(x.timestamp_consent3 != 0, "RR58");
        require(x.consent3 == true, "RR64");
        require((block.timestamp - x.timestamp_consent3) <= 2*timeLimit, "RR8"); //timelimit is made doubled, as administrating vaccine physically might take some times!

        require(x.timestamp_vaccination == 0, "RR89");
        x.timestamp_vaccination = block.timestamp;
        vaccineInjectingProtocol[_latestProtocolNo] = x;
    }

    /**
    Caller: Citizen
    When: After the VC registers the vaccination timestamp, the citizen must confirm it by sending an acknowledgment of vaccination 
          to the SC, through this function within the specified time limit. A positive acknowledgment triggers the instant transfer 
          of the service charge to the VC, and the VC's locked funds are also released. Additionally, the vaccine injection protocol 
          successfully concludes.
    Previous Function: registerVaccinationTimestamp by VC
    **/
    function acknowledgeVaccination(uint256 _vcID, bool _ack) external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        uint256 _latestProtocolNo = latestVaccineInjectingProtocolNumber[msg.sender];
        require(injectingProtocolCurrentlyRuns[_latestProtocolNo] == true, "RR34");
        
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];

        require(_vcID == x.vcID, "RR37"); //Authenticating VC

        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        require(_tokenID == x.tokenID, "RR36"); //Authenticating Citizen
        instance_SC_Requirements_Check.checkForCitizenNotYetVaccinated(_tokenID);
        
        require(x.timestamp_vaccination != 0, "RR90");
        require((block.timestamp - x.timestamp_vaccination) <= timeLimit, "RR8");
        require(x.timestamp_acknowledgement == 0, "RR91");

        x.acknowledge_vaccination = _ack;
        x.timestamp_acknowledgement = block.timestamp;
        if(_ack == true)
        {
            instance_SC_C_Govt_1.setVaccinationStatus(_tokenID);

            //Transfer Locked Money & Service Charge to VC..
            address _vcAddr = instance_SC_VC_Govt.getvcAddr(_vcID);
            payable(_vcAddr).transfer(lockingAmount); //unlocking VC's money..
            instance_SC_VC_Govt.payServiceCharge(_vcAddr);
            x.money_received_by_VC = lockingAmount;
            x.timestamp_receive_money_by_VC = block.timestamp;
            //Citizen's Locked Money can only be released after successful completion of Vaccine Passport Generation

            instance_SC_VC_Govt.setVialState(x.commit_vialID, 1); //Mark vaccine vial as "SPENT"
            instance_SC_C_Govt_1.setVaccinationStatus(_tokenID); //Change Vaccination Status of the Citizen to "True"

            //Terminate Injecting Protocol..
            injectingProtocolCurrentlyRuns[_latestProtocolNo] = false;
        }
        vaccineInjectingProtocol[_latestProtocolNo] = x;
    }

    
    //Interface for other functions

    function getProtocolDetails(uint256 _latestProtocolNo) external view returns(uint256, uint256, uint256, uint256, uint256, uint256, bytes32, uint256, bool, uint256, bytes32, uint256, bool, uint256, bool, uint256, bytes32[] memory, uint256, uint256, bool, uint256, uint256, uint256, uint256, uint256)
    {
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];
        return(x.tokenID, x.vcID, x.timestamp_send_tokenID, x.timestamp_lock_money_by_VC, x.timestamp_lock_money_by_C, x.stockID, x.commit_MT_Proof, x.timestamp_commit_MT_Proof, x.consent1, x.timestamp_consent1, x.commit_vialID, x.timestamp_commit_vialID, x.consent2, x.timestamp_consent2, x.consent3, x.timestamp_consent3, x.proof_submitted_by_VC, x.timestamp_proof_submission, x.timestamp_vaccination, x.acknowledge_vaccination, x.timestamp_acknowledgement, x.money_received_by_VC, x.timestamp_receive_money_by_VC, x.money_received_by_C, x.timestamp_receive_money_by_C);
    }

    function getProtocolNoAndStatus(address _cAddr) external view returns(uint256, bool)
    {
        uint256 _latestProtocolNo = latestVaccineInjectingProtocolNumber[_cAddr];
        return(_latestProtocolNo, injectingProtocolCurrentlyRuns[_latestProtocolNo]);    
    }

    function abortProtocol(uint256 _latestProtocolNo) external
    {
        injectingProtocolCurrentlyRuns[_latestProtocolNo] = false;
        protocolAborted[_latestProtocolNo] = true;
    }
    
    function transferMoneyToVC(address _vcAddr, uint256 _latestProtocolNo) external
    {
        payable(_vcAddr).transfer(lockingAmount);
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];
        x.money_received_by_VC = lockingAmount;
        x.timestamp_receive_money_by_VC = block.timestamp;
        vaccineInjectingProtocol[_latestProtocolNo] = x;
    }
    
    function penalizeVCAndTransferMoneyToC(address _cAddr, uint256 _latestProtocolNo) external
    {
        payable(_cAddr).transfer(2*lockingAmount); //unlocking own's money + VC's locked money..
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];
        x.money_received_by_C = 2*lockingAmount;
        x.timestamp_receive_money_by_C = block.timestamp;
        x.money_received_by_VC = 0;
        x.timestamp_receive_money_by_VC = block.timestamp;
        vaccineInjectingProtocol[_latestProtocolNo] = x;
    }

    function penalizeCAndTransferMoneyToVC(address _vcAddr, uint256 _latestProtocolNo) external
    {
        payable(_vcAddr).transfer(2*lockingAmount); //unlocking own's money + citizen's locked money
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];
        x.money_received_by_VC = 2*lockingAmount;
        x.timestamp_receive_money_by_VC = block.timestamp;
        x.money_received_by_C = 0;
        x.timestamp_receive_money_by_C = block.timestamp;
        vaccineInjectingProtocol[_latestProtocolNo] = x;
    }
    
    function submitProof(bytes32[] memory _hashes, uint256 _latestProtocolNo) external
    {
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];
        x.proof_submitted_by_VC = _hashes;
        x.timestamp_proof_submission = block.timestamp;
        vaccineInjectingProtocol[_latestProtocolNo] = x;
    }

    function payDueAmountOfCitizen(address _cAddr) external
    {
        uint256 _latestProtocolNo = latestVaccineInjectingProtocolNumber[_cAddr];
        VaccineInjectingProtocol memory x = vaccineInjectingProtocol[_latestProtocolNo];
        if(x.timestamp_receive_money_by_C == 0 && x.money_received_by_VC == lockingAmount && x.money_received_by_C == 0)
        {
            payable(_cAddr).transfer(lockingAmount);
            x.money_received_by_C = lockingAmount;
            x.timestamp_receive_money_by_C = block.timestamp;
            vaccineInjectingProtocol[_latestProtocolNo] = x;
        }
    }
   
}