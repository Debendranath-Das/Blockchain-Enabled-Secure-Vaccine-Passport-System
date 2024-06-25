// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
import "./SC_VC_Govt.sol";
import "./SC_C_Govt_1.sol";
import "./SC_C_VC_1.sol";
import "./SC_Requirements_Check.sol";
import "./MerkleProofLibrary.sol";

contract SC_C_Govt_2
{
    address public addr_SC_VC_Govt;
    SC_VC_Govt instance_SC_VC_Govt;

    address public addr_SC_C_Govt_1;
    SC_C_Govt_1 instance_SC_C_Govt_1;

    address public addr_SC_C_VC_1;
    SC_C_VC_1 instance_SC_C_VC_1;

    address public addr_SC_Requirements_Check;
    SC_Requirements_Check instance_SC_Requirements_Check;

    struct VaccinePassportApplication
    {
        uint256 applicant_tokenID;
        uint256 timestamp_lock_money_by_C;
        uint256 timestamp_lock_money_by_Govt;
        uint256 timestamp_provide_vaccination_proof;
        bool consent1;
        uint256 timestamp_consent1;
        bool consent2;
        uint256 timestamp_consent2;
        uint256 timestamp_disclose_proof;
        uint256 timestamp_issue_vp;
        uint256 money_received_by_C;
        uint256 timestamp_receive_money_by_C;
        uint256 money_received_by_Govt;
        uint256 timestamp_receive_money_by_Govt;
    }

    struct CreationOfVaccinePassport
    {
        //Entirely populated by Govt
        bytes32 message_digest_vp;
        string sig_on_message_digest_vp; 
        string cID; 
        uint256 timestamp_issue_vp;
    }
    
    mapping(address => uint256) latestVPApplNumber; //Maps: citizen Addr -> Latest Vaccine Passport Application No
    mapping(uint256 => bool) vpApplUnderProcess; //Maps: Vaccine Passport Application Number -> is currently under consideration? (boolean)
    mapping(uint256 => bool) vpApplAborted; //Maps: Vaccine Passport Application Number -> is protocol aborted? (boolean)
    mapping(uint256 => VaccinePassportApplication) vpAppl; //Maps: Vaccine Passport Application Number -> Application details
    mapping(uint256 => uint256) noOfTimesAppliedForVP; //Maps: Citizen's Token IS -> no of times applied for Vaccine Passport
    mapping(uint256 => CreationOfVaccinePassport) getVPInfo; //Maps: Citizen's Token ID -> Vaccine Passport Info

    uint256 public VPApplNumberGenerator = 0;
    uint256 public constant timeLimit = 300 seconds;
    uint256 public constant lockingAmount = 500 wei;

    
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
    Caller: Citizen (holding a valid TokenID and vaccinated, not yet obtained Vaccine Passport)
    When: Citizen initiates Vaccine Passport Application Process by locking money into SC.
    Previous Function: NA
    **/
    function initiateVPApplAndlockMoney() external payable
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        instance_SC_Requirements_Check.checkVaccinationAndVPStatusOfCitizen(_tokenID);

        bool _isInjectingProtocolRunning;
        (, _isInjectingProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(msg.sender);
        require(_isInjectingProtocolRunning == false, "RR33");

        uint256 _latestVPApplNo = latestVPApplNumber[msg.sender];
        require(vpApplUnderProcess[_latestVPApplNo] == false, "RR99");
        require(msg.value == lockingAmount, "RR38");

        VPApplNumberGenerator += 1;
        _latestVPApplNo = VPApplNumberGenerator;
        latestVPApplNumber[msg.sender] = _latestVPApplNo;

        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        x.applicant_tokenID = _tokenID;
        x.timestamp_lock_money_by_C = block.timestamp;

        vpAppl[_latestVPApplNo] = x;
        vpApplUnderProcess[_latestVPApplNo] = true;

        noOfTimesAppliedForVP[_tokenID] += 1;
    }

    /**
    Caller: Govt
    When: Once citizen initiates the vaccine passport application, 
          the Govt calls the function to lock money on SC.
    Previous Function: initiateVPAppl() by Citizen
    **/
    function lockMoneyByGovt(address _cAddr) external payable
    {
        require(msg.sender == instance_SC_VC_Govt.getGovt()); //Authenticating Govt

        instance_SC_Requirements_Check.checkForValidCitizenTokenID(_cAddr);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);
        instance_SC_Requirements_Check.checkVaccinationAndVPStatusOfCitizen(_tokenID);

        uint256 _latestVPApplNo = latestVPApplNumber[_cAddr];
        require(vpApplUnderProcess[_latestVPApplNo] == true, "RR100");

        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        require(x.applicant_tokenID == _tokenID, "RR36"); //Authenticating Citizen

        require(msg.value == lockingAmount, "RR38");

        require(x.timestamp_lock_money_by_C != 0, "RR101");
        require((block.timestamp - x.timestamp_lock_money_by_C) <= timeLimit, "RR8");
        require(x.timestamp_lock_money_by_Govt == 0, "RR102");

        x.timestamp_lock_money_by_Govt = block.timestamp;
        vpAppl[_latestVPApplNo] = x;
    }

    /**
    Caller: Citizen
    When: Once Govt locks the money, the Citizen provides vialID and the commitment value of MT_Proof.
    Previous Function: lockMoneyByGovt() by Govt
    **/
    function sendVaccinationProof(string memory _vID, bytes32 _commit_MT_Proof) external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        instance_SC_Requirements_Check.checkVaccinationAndVPStatusOfCitizen(_tokenID);

        uint256 _latestVPApplNo = latestVPApplNumber[msg.sender];
        require(vpApplUnderProcess[_latestVPApplNo] == true, "RR100");

        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        require(x.applicant_tokenID == _tokenID, "RR36"); //Authenticating Citizen

        uint256 _vaccineInjectingProtocolNo;
        bool _isProtocolRunning;
        (_vaccineInjectingProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(msg.sender);
        require(_isProtocolRunning == false, "RR33");
        
        bytes32 commit_MT_Proof;
        bytes32 commit_vialID;
        (, , , , , , commit_MT_Proof, , , , commit_vialID, , , , , , , , , , , , , , ) = instance_SC_C_VC_1.getProtocolDetails(_vaccineInjectingProtocolNo);
        
        require(_commit_MT_Proof == commit_MT_Proof, "RR104");

        bytes32 _vialHash = keccak256(abi.encodePacked(_vID));
        require(_vialHash == commit_vialID, "RR105");

        instance_SC_Requirements_Check.checkForSpentVaccineVial(_vialHash);
        
        require(x.timestamp_lock_money_by_Govt != 0, "RR106");
        require(x.timestamp_provide_vaccination_proof == 0, "RR107");
        require((block.timestamp - x.timestamp_lock_money_by_Govt) <= timeLimit, "RR8");

        x.timestamp_provide_vaccination_proof = block.timestamp;
        vpAppl[_latestVPApplNo] = x;
    }

    /**
    Caller: Govt
    When: Next Govt sends its consent1/dissent1 based on the received proof.
    Previous Function: sendVaccinationProof() by Citizen
    **/
    function sendConsent1(address _cAddr, bool _consent1) external
    {
        require(msg.sender == instance_SC_VC_Govt.getGovt()); //Authenticating Govt

        instance_SC_Requirements_Check.checkForValidCitizenTokenID(_cAddr);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);
        instance_SC_Requirements_Check.checkVaccinationAndVPStatusOfCitizen(_tokenID);

        uint256 _latestVPApplNo = latestVPApplNumber[_cAddr];
        require(vpApplUnderProcess[_latestVPApplNo] == true, "RR100");

        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        require(x.applicant_tokenID == _tokenID, "RR36"); //Authenticating Citizen
        
        require(x.timestamp_provide_vaccination_proof != 0, "RR108");
        require(x.timestamp_consent1 == 0, "RR109");
        require((block.timestamp - x.timestamp_provide_vaccination_proof) <= timeLimit, "RR8");

        x.consent1 = _consent1;
        x.timestamp_consent1 = block.timestamp;
        if(_consent1 == false)
        {
            //Abort the current protocol, unlock and trasfer money..
            vpApplUnderProcess[_latestVPApplNo] = false;
            vpApplAborted[_latestVPApplNo] = true;
            payable(msg.sender).transfer(lockingAmount);
            payable(_cAddr).transfer(lockingAmount);
            x.money_received_by_C = lockingAmount;
            x.money_received_by_Govt = lockingAmount;
            x.timestamp_receive_money_by_C = block.timestamp;
            x.timestamp_receive_money_by_Govt = block.timestamp;
        }
        vpAppl[_latestVPApplNo] = x;
    }

    /**
    Caller: Govt
    When: Sending consent1 Govt verifies membership proof for the vial ID and call this function as verfication result.
    Previous Function: sendConsent1() by Citizen
    **/
    function sendConsent2(address _cAddr, bool _consent2) external
    {
        require(msg.sender == instance_SC_VC_Govt.getGovt()); //Authenticating Govt

        instance_SC_Requirements_Check.checkForValidCitizenTokenID(_cAddr);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);
        instance_SC_Requirements_Check.checkVaccinationAndVPStatusOfCitizen(_tokenID);

        uint256 _latestVPApplNo = latestVPApplNumber[_cAddr];
        require(vpApplUnderProcess[_latestVPApplNo] == true, "RR100");

        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        require(x.applicant_tokenID == _tokenID, "RR36"); //Authenticating Citizen
        
        require(x.timestamp_consent1 != 0, "RR110");
        require(x.consent1 == true, "RR111");
        require(x.timestamp_consent2 == 0, "RR112");
        require((block.timestamp - x.timestamp_consent1) <= timeLimit, "RR8");

        x.consent2 = _consent2;
        x.timestamp_consent2 = block.timestamp;

        vpAppl[_latestVPApplNo] = x;
    }

    /**
    Caller: Govt
    When: Once the Govt provides positive consent2, it will begin generating the vaccine passport(VP) for the citizen.
          Govt computes the VP's message digest(MD), makes a signature on MD, and uploads this information on BC for accountability.
          Then Govt encrypts the citizen's VP and uploads it to IPFS, then store the IPFS's content identifier, i.e. CID, on BC.    
    Previous Function: sendConsent2 by Govt
    */
    function uploadVPInfo(address _cAddr, bytes32 _MD_VP, string memory _sign, string memory _cID) external 
    {
        require(msg.sender == instance_SC_VC_Govt.getGovt()); //Authenticating Govt

        instance_SC_Requirements_Check.checkForValidCitizenTokenID(_cAddr);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);
        instance_SC_Requirements_Check.checkVaccinationAndVPStatusOfCitizen(_tokenID);

        uint256 _latestVPApplNo = latestVPApplNumber[_cAddr];
        require(vpApplUnderProcess[_latestVPApplNo] == true, "RR100");

        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        require(x.applicant_tokenID == _tokenID, "RR36"); //Authenticating Citizen
        
        require(x.timestamp_consent2 != 0, "RR113");
        require(x.consent2 == true, "RR114");
        require(x.timestamp_issue_vp == 0, "RR115");
        require((block.timestamp - x.timestamp_consent2) <= timeLimit, "RR8");

        getVPInfo[_tokenID] = CreationOfVaccinePassport(_MD_VP, _sign, _cID, block.timestamp);
        //change vaccination status of citizen..
        instance_SC_C_Govt_1.issueVaccinePassport(_tokenID, _cID, _MD_VP, _sign, block.timestamp);

        //Transfer Locked Money & Service Charge..
        payable(msg.sender).transfer(lockingAmount); //unlocking Govt own's money..
        payable(_cAddr).transfer(lockingAmount); //unlocking Citizen's money for this protocol..
        instance_SC_C_VC_1.payDueAmountOfCitizen(_cAddr); //unlocking Citizen's due for injecting protocol, if any..
        x.money_received_by_Govt = lockingAmount;
        x.money_received_by_C = lockingAmount;
        x.timestamp_receive_money_by_Govt = block.timestamp;
        x.timestamp_receive_money_by_C = block.timestamp;

        x.timestamp_issue_vp = block.timestamp;
        vpAppl[_latestVPApplNo] = x;
        
        //Terminate Vaccine Passport Application Process..
        vpApplUnderProcess[_latestVPApplNo] = false;

    } 

    //Exit Functions..

    /**
    Caller: Citizen
    When: If the Govt doesn't respond within timeout once the citizen initiates VP application process, 
          the citizen can unlock its locked money and protocol is aborted.
    Previous Function: initiateVPApplAndlockMoney() by C (Ideal Case: lockMoneyByGovt() by Govt)
    */
    function quit1ByC() external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        uint256 _latestVPApplNo = latestVPApplNumber[msg.sender];
        require(vpApplUnderProcess[_latestVPApplNo] == true, "RR100");
        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        require(x.applicant_tokenID == _tokenID, "RR36"); //Authenticating Citizen
        require(x.timestamp_lock_money_by_C != 0, "RR101");
        require(x.timestamp_lock_money_by_Govt == 0, "RR102");
        require((block.timestamp - x.timestamp_lock_money_by_C) > timeLimit, "RR116");
        payable(msg.sender).transfer(lockingAmount);
        x.money_received_by_C = lockingAmount;
        x.timestamp_receive_money_by_C = block.timestamp;
        vpAppl[_latestVPApplNo] = x;
        vpApplUnderProcess[_latestVPApplNo] = false;
        vpApplAborted[_latestVPApplNo] = true;
    }

    /**
    Caller: Govt
    When: If the citizen does not provide vaccination proof within timeout, Govt 
          can quit the protocol unlocking its money. In this case, citizen will be penalized!
    Previous Function: lockMoneyByGovt() by Govt (Ideal Case: sendVaccinationProof)
    **/
    function quit2ByGovt(address _cAddr) external
    {
        require(msg.sender == instance_SC_VC_Govt.getGovt()); //Authenticating Govt
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(_cAddr);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);
        uint256 _latestVPApplNo = latestVPApplNumber[msg.sender];
        require(vpApplUnderProcess[_latestVPApplNo] == true, "RR100");
        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        require(x.applicant_tokenID == _tokenID, "RR36"); //Authenticating Citizen
        require(x.timestamp_lock_money_by_Govt != 0, "RR106");
        require(x.timestamp_provide_vaccination_proof == 0, "RR107");
        require((block.timestamp - x.timestamp_lock_money_by_Govt) > timeLimit, "RR117");       
        payable(msg.sender).transfer(2*lockingAmount);
        x.money_received_by_Govt = 2*lockingAmount;
        x.timestamp_receive_money_by_Govt = block.timestamp;
        x.money_received_by_C = 0;
        x.timestamp_receive_money_by_C = block.timestamp;
        vpAppl[_latestVPApplNo] = x;
        vpApplUnderProcess[_latestVPApplNo] = false;
        vpApplAborted[_latestVPApplNo] = true;
    }

    /**
    Caller: Citizen
    When: If the Govt doesn't provide its first consent within time limit, citizen can quit the protocol.
    Previous Function: sendVaccinationProof() by C (Ideal Case: sendConsent1 by Govt)
    */
    function quit3ByC() external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        uint256 _latestVPApplNo = latestVPApplNumber[msg.sender];
        require(vpApplUnderProcess[_latestVPApplNo] == true, "RR100");
        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        require(x.applicant_tokenID == _tokenID, "RR36"); //Authenticating Citizen
        require(x.timestamp_provide_vaccination_proof != 0, "RR108");
        require(x.timestamp_consent1 == 0, "RR109");
        require((block.timestamp - x.timestamp_provide_vaccination_proof) > timeLimit, "RR116");
        payable(msg.sender).transfer(2*lockingAmount);
        x.money_received_by_C = 2*lockingAmount;
        x.timestamp_receive_money_by_C = block.timestamp;
        x.money_received_by_Govt = 0;
        x.timestamp_receive_money_by_Govt = block.timestamp;
        vpAppl[_latestVPApplNo] = x;
        vpApplUnderProcess[_latestVPApplNo] = false;
        vpApplAborted[_latestVPApplNo] = true;
    }

    /**
    Caller: Citizen
    When: After providing the first consent if the Govt doesn't provide its second consent within time limit, citizen can quit the protocol.
    Previous Function: sendConsent1() by Govt (Ideal Case: sendConsent2 by Govt)
    */
    function quit4ByC() external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        uint256 _latestVPApplNo = latestVPApplNumber[msg.sender];
        require(vpApplUnderProcess[_latestVPApplNo] == true, "RR100");
        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        require(x.applicant_tokenID == _tokenID, "RR36"); //Authenticating Citizen
        require(x.timestamp_consent1 != 0, "RR110");
        require(x.timestamp_consent2 == 0, "RR112");
        require((block.timestamp - x.timestamp_consent1) > timeLimit, "RR116");
        payable(msg.sender).transfer(2*lockingAmount);
        x.money_received_by_C = 2*lockingAmount;
        x.timestamp_receive_money_by_C = block.timestamp;
        x.money_received_by_Govt = 0;
        x.timestamp_receive_money_by_Govt = block.timestamp;
        vpAppl[_latestVPApplNo] = x;
        vpApplUnderProcess[_latestVPApplNo] = false;
        vpApplAborted[_latestVPApplNo] = true;
    }

    /**
    Caller: Govt
    When: If Govt sends FALSE consent2, then it needs to give proof of misbehaviour within time limit by calling this function.
    Previous Function: sendConsent2 by Govt
    */
    function discloseProof(address _cAddr, bytes32[] memory _hashes) external
    {
        require(msg.sender == instance_SC_VC_Govt.getGovt()); //Authenticating Govt

        instance_SC_Requirements_Check.checkForValidCitizenTokenID(_cAddr);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);
        instance_SC_Requirements_Check.checkVaccinationAndVPStatusOfCitizen(_tokenID);

        uint256 _latestVPApplNo = latestVPApplNumber[_cAddr];
        require(vpApplUnderProcess[_latestVPApplNo] == true, "RR100");

        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        require(x.applicant_tokenID == _tokenID, "RR36"); //Authenticating Citizen
        
        //require(x.consent1 == true, "RR111");
        require(x.timestamp_consent2 != 0, "RR113");
        require(x.consent2 == false, "RR118");
        require(x.timestamp_disclose_proof == 0, "RR119");
        require((block.timestamp - x.timestamp_consent2) <= timeLimit, "RR8");

        uint256 _vaccineInjectingProtocolNo;
        bool _isProtocolRunning;
        (_vaccineInjectingProtocolNo, _isProtocolRunning) = instance_SC_C_VC_1.getProtocolNoAndStatus(msg.sender);
        require(_isProtocolRunning == false, "RR33");
        
        uint256 stockID;
        bytes32 commit_MT_Proof;
        bytes32 commit_vialID;
        (, , , , , stockID, commit_MT_Proof, , , , commit_vialID, , , , , , , , , , , , , , ) = instance_SC_C_VC_1.getProtocolDetails(_vaccineInjectingProtocolNo);

        x.timestamp_disclose_proof = block.timestamp;

        if( commit_MT_Proof != keccak256(abi.encodePacked(_hashes)) ) //Govt is malicious as wrongly sent CONSENT1 as TRUE!
        {
            //Penalize Govt, unlock and trasfer money..
            payable(_cAddr).transfer(2*lockingAmount);
            x.money_received_by_C = 2*lockingAmount;
            x.timestamp_receive_money_by_C = block.timestamp;
            x.money_received_by_Govt = 0;
            x.timestamp_receive_money_by_Govt = block.timestamp;
            vpAppl[_latestVPApplNo] = x;
            vpApplUnderProcess[_latestVPApplNo] = false;
            vpApplAborted[_latestVPApplNo] = true;
            return;
        }

        bytes32 _MR_Root;
        (,,,_MR_Root) = instance_SC_VC_Govt.getStockInfo(stockID);
        bytes32 leaf = commit_vialID;
        if( MerkleProof.verify(_hashes, _MR_Root, leaf) != true ) //Citizen is malicious.
        {
            //Penalize C, unlock and trasfer money..  
            payable(msg.sender).transfer(2*lockingAmount);
            x.money_received_by_Govt = 2*lockingAmount;
            x.timestamp_receive_money_by_Govt = block.timestamp;
            x.money_received_by_C = 0;
            x.timestamp_receive_money_by_C = block.timestamp;
            
            vpAppl[_latestVPApplNo] = x;
            vpApplUnderProcess[_latestVPApplNo] = false;
            vpApplAborted[_latestVPApplNo] = true;
            return;
        }
        //Govt is malicious.
        //Penalize Govt, unlock and trasfer money..
        payable(_cAddr).transfer(2*lockingAmount);
        x.money_received_by_C = 2*lockingAmount;
        x.timestamp_receive_money_by_C = block.timestamp;
        x.money_received_by_Govt = 0;
        x.timestamp_receive_money_by_Govt = block.timestamp;
        vpAppl[_latestVPApplNo] = x;
        vpApplUnderProcess[_latestVPApplNo] = false;
        vpApplAborted[_latestVPApplNo] = true;
    }

    /**
    Caller: Citizen
    When: If Govt does not disclose the proof within timelimit after sending FALSE consent2, then the
          citizen can unlock money and abort the protocol. Govt is penalized in this case.
    Previous Function: sendConsent2 by Govt (Ideal case: discloseProof() by Govt)
    */
    function quit5ByC() external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        uint256 _latestVPApplNo = latestVPApplNumber[msg.sender];
        require(vpApplUnderProcess[_latestVPApplNo] == true, "RR100");
        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        require(x.applicant_tokenID == _tokenID, "RR36"); //Authenticating Citizen
        require(x.timestamp_consent2 != 0, "RR113");
        require(x.consent2 == false, "RR118");
        require(x.timestamp_disclose_proof == 0, "RR119");
        require((block.timestamp - x.timestamp_consent2) > timeLimit, "RR116");
        payable(msg.sender).transfer(2*lockingAmount);
        x.money_received_by_C = 2*lockingAmount;
        x.timestamp_receive_money_by_C = block.timestamp;
        x.money_received_by_Govt = 0;
        x.timestamp_receive_money_by_Govt = block.timestamp;
        vpAppl[_latestVPApplNo] = x;
        vpApplUnderProcess[_latestVPApplNo] = false;
        vpApplAborted[_latestVPApplNo] = true;
    }

    /**
    Caller: Citizen
    When: Providing the consent2 as TRUE, if the Govt doesn't issue the citizen's vaccine passport within time limit,
          citizen can quit the protocol.
    Previous Function: sendConsent2() by Govt (Ideal Case: uploadVPInfoAndGetPayment by Govt)
    */
    function quit6ByC() external
    {
        instance_SC_Requirements_Check.checkForValidCitizenTokenID(msg.sender);
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        uint256 _latestVPApplNo = latestVPApplNumber[msg.sender];
        require(vpApplUnderProcess[_latestVPApplNo] == true, "RR100");
        VaccinePassportApplication memory x = vpAppl[_latestVPApplNo];
        require(x.applicant_tokenID == _tokenID, "RR36"); //Authenticating Citizen
        require(x.timestamp_consent2 != 0, "RR113");
        require(x.consent2 == true, "RR114");
        require(x.timestamp_issue_vp == 0, "RR115");
        require((block.timestamp - x.timestamp_consent2) > timeLimit, "RR116");
        payable(msg.sender).transfer(2*lockingAmount);
        x.money_received_by_C = 2*lockingAmount;
        x.timestamp_receive_money_by_C = block.timestamp;
        x.money_received_by_Govt = 0;
        x.timestamp_receive_money_by_Govt = block.timestamp;
        vpAppl[_latestVPApplNo] = x;
        vpApplUnderProcess[_latestVPApplNo] = false;
        vpApplAborted[_latestVPApplNo] = true;
    }

    // Interface for Other Functions
    function getVPDetails(uint256 _tokenID) external view returns(bytes32, string memory, string memory, uint256)
    {
        CreationOfVaccinePassport memory x = getVPInfo[_tokenID];
        return(x.message_digest_vp,x.sig_on_message_digest_vp,x.cID,x.timestamp_issue_vp);
    }
}