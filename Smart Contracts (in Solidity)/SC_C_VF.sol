// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
import "./SC_C_Govt_1.sol";

contract SC_C_VF
{
    address addr_SC_C_Govt_1;
    SC_C_Govt_1 instance_SC_C_Govt_1;

    struct VerificationOfVP
    {
        uint256 verificationTaskID;
        address cAddr;
        uint256 tokenID;
        address vfAddr;
        uint256 timestamp_lock_money_by_VF;
        bytes32 commit_RK;
        uint256 timestamp_lock_money_and_commit_RK_by_C;
        bool consent;
        uint256 timestamp_provide_consent;
        uint256 timestamp_grant_permission;
        uint256 timestamp_verification_result;
        uint256 timestamp_unlock_money;
        bool isValidVP;
    }
    uint256 verificationTaskIDGenerator = 0;
    uint256 constant timelimit = 300 seconds;
    uint256 constant lockingAmount = 500 wei;

    mapping(uint256 => VerificationOfVP) public verifyVP; //Maps: Verification Task ID -> struct VerificationOfVP
    mapping(uint256 => mapping(address => bool)) public accessControl; //Maps: Citizen's Token ID * Verifier's Address -> bool
    mapping(uint256 => mapping(address => bool)) public verificationProtocolCurrentlyRuns; //Maps: Citizen's Token ID * Verifier's Address -> bool

    constructor(address _addr_SC_C_Govt_1) 
    {
        addr_SC_C_Govt_1 = _addr_SC_C_Govt_1;
        instance_SC_C_Govt_1 = SC_C_Govt_1(addr_SC_C_Govt_1);
    }

    /**
    Caller: Verifier
    When: To initiate the Vaccine Passport Verification Process, the verfier seeks permission from 
          the citizen and locks money. A unique verfication task ID gets generated.
    Previous Function: NA
    **/
    function lockMoney(address _cAddr) external payable returns(uint256)
    {
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(_cAddr);
        require(_tokenID != 0,"RR61");
        bool _vaccination_status;
        bool _vp_status;
        (,,_vaccination_status, _vp_status) = instance_SC_C_Govt_1.getCitizen(_tokenID);
        require(_vaccination_status == true,"RR97");
        require(_vp_status == true, "RR120");
        require(verificationProtocolCurrentlyRuns[_tokenID][msg.sender] == false, "RR69");
        require(msg.value == lockingAmount, "RR71");
        verificationTaskIDGenerator++;
        verifyVP[verificationTaskIDGenerator] = VerificationOfVP(verificationTaskIDGenerator, _cAddr, _tokenID, msg.sender, block.timestamp, bytes32(0), 0, false, 0, 0, 0, 0, false);
        verificationProtocolCurrentlyRuns[_tokenID][msg.sender] = true;
        return(verificationTaskIDGenerator);
    }

    /**
    Caller: Citizen
    When: Once the verifier locks money and initiates the verfication process, the citizen also locks 
          the money within a fixed timelimit and commits the Re-encryption Key.
    Previous Function: lockMoney() by VF
    **/
    function lockMoneyAndcommitRK(uint256 _verificationTaskID, bytes32 _commitRK) external payable
    {
        require(_verificationTaskID >0 && _verificationTaskID <= verificationTaskIDGenerator,"RR72");
        VerificationOfVP memory _vpVerify = verifyVP[_verificationTaskID];
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        require(_vpVerify.tokenID == _tokenID, "RR73");
        require(_vpVerify.timestamp_unlock_money == 0, "RR74");
        require(verificationProtocolCurrentlyRuns[_tokenID][_vpVerify.vfAddr] == true, "RR70");
        require(msg.value == lockingAmount, "RR71");
        require(_vpVerify.timestamp_lock_money_and_commit_RK_by_C == 0, "RR77");
        require((block.timestamp - _vpVerify.timestamp_lock_money_by_VF) <= timelimit, "RR8");
        _vpVerify.timestamp_lock_money_and_commit_RK_by_C = block.timestamp;
        _vpVerify.commit_RK = _commitRK;
        verifyVP[_verificationTaskID] = _vpVerify;
    }

    /**
    Caller: Verifier
    When: If the citizen does not respond by locking money on smart contract within the timeout period,
          after initiation of the verification process, verifier can withdraw the locked money.
    Previous Function: lockMoney() by VF (IDEAL Case: lockMoneyAndcommitRK() by C)
    **/
    function quit1ByVF(uint256 _verificationTaskID) external
    {
        require(_verificationTaskID >0 && _verificationTaskID <= verificationTaskIDGenerator,"RR72");
        VerificationOfVP memory _vpVerify = verifyVP[_verificationTaskID];
        require(_vpVerify.vfAddr == msg.sender, "RR73");
        require(_vpVerify.timestamp_unlock_money == 0, "RR74");
        require(verificationProtocolCurrentlyRuns[_vpVerify.tokenID][_vpVerify.vfAddr] == true, "RR70");
        require(_vpVerify.timestamp_lock_money_by_VF != 0, "RR75");
        require(_vpVerify.timestamp_lock_money_and_commit_RK_by_C == 0 && (block.timestamp - _vpVerify.timestamp_lock_money_by_VF) > timelimit, "RR76");
        payable(msg.sender).transfer(lockingAmount);
        _vpVerify.timestamp_unlock_money = block.timestamp;
        verifyVP[_verificationTaskID] = _vpVerify;
        verificationProtocolCurrentlyRuns[_vpVerify.tokenID][_vpVerify.vfAddr] = false;
    }

    /**
    Caller: Verfier
    When: Receiving RK in offchain, the verifier provides its consent if the received RK matches its
          commitment.
    Previous Function: fetchVPInfo() by verifier
    **/
    function provideConsent(uint256 _verificationTaskID, bool _decision) external
    {
        require(_verificationTaskID >0 && _verificationTaskID <= verificationTaskIDGenerator,"RR72");
        VerificationOfVP memory _vpVerify = verifyVP[_verificationTaskID];
        require(_vpVerify.vfAddr == msg.sender, "RR73");
        require(_vpVerify.timestamp_unlock_money == 0, "RR74");
        require(verificationProtocolCurrentlyRuns[_vpVerify.tokenID][msg.sender] == true, "RR70");
        require(_vpVerify.timestamp_lock_money_and_commit_RK_by_C != 0, "RR78");
        require(_vpVerify.timestamp_provide_consent == 0, "RR79");
        require((block.timestamp - _vpVerify.timestamp_lock_money_and_commit_RK_by_C) <= timelimit, "RR8");
        _vpVerify.consent = _decision;
        _vpVerify.timestamp_provide_consent = block.timestamp;
        if(_decision == false) //Unlock individual party's money.
        {
            payable(msg.sender).transfer(lockingAmount);
            payable(_vpVerify.cAddr).transfer(lockingAmount);
            _vpVerify.timestamp_unlock_money = block.timestamp;
            verificationProtocolCurrentlyRuns[_vpVerify.tokenID][_vpVerify.vfAddr] = false;
        }
        verifyVP[_verificationTaskID] = _vpVerify;
    }

    /**
    Caller: Citizen
    When: After sending the RK to verifier, if the verifier does not provide it's consent within timeout,
          the citizen can withdraw its locked money. Here, the system will not penalize the verfier
          as it might be possible that the key - RK is lost in the network. Or the citizen not at all
          sent the key to VF, although key commitment has been done on BC.
    Previous Function: lockMoneyAndcommitRK() by C (IDEAL Case: provideConsent() by VF)
    **/
    function quit2ByC(uint256 _verificationTaskID) external
    {
        require(_verificationTaskID >0 && _verificationTaskID <= verificationTaskIDGenerator,"RR72");
        VerificationOfVP memory _vpVerify = verifyVP[_verificationTaskID];
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        require(_vpVerify.tokenID == _tokenID, "RR73");
        require(_vpVerify.timestamp_unlock_money == 0, "RR74");
        require(verificationProtocolCurrentlyRuns[_vpVerify.tokenID][_vpVerify.vfAddr] == true, "RR70");
        require(_vpVerify.timestamp_lock_money_and_commit_RK_by_C != 0, "RR75");
        require(_vpVerify.timestamp_provide_consent == 0 && (block.timestamp - _vpVerify.timestamp_lock_money_and_commit_RK_by_C) > timelimit, "RR76");
        payable(msg.sender).transfer(lockingAmount);
        payable(_vpVerify.vfAddr).transfer(lockingAmount);
        _vpVerify.timestamp_unlock_money = block.timestamp;
        verifyVP[_verificationTaskID] = _vpVerify;
        verificationProtocolCurrentlyRuns[_vpVerify.tokenID][_vpVerify.vfAddr] = false;
    }

    /**
    Caller: Citizen
    When: Once the verifier sends its positive consent, the citizen must grant access permission to
          the verifier, so that it can fetch useful info about the vaccine passport.
    Previous Function: provideConsent() by verifier
    **/
    function grantAccessPermission(uint256 _verificationTaskID) external
    {
        require(_verificationTaskID >0 && _verificationTaskID <= verificationTaskIDGenerator,"RR72");
        VerificationOfVP memory _vpVerify = verifyVP[_verificationTaskID];
        require(_vpVerify.cAddr == msg.sender, "RR73");
        require(_vpVerify.timestamp_unlock_money == 0, "RR74");
        require(verificationProtocolCurrentlyRuns[_vpVerify.tokenID][_vpVerify.vfAddr] == true, "RR70");
        require(_vpVerify.timestamp_provide_consent != 0, "RR80");
        require(_vpVerify.consent == true, "RR81");
        require(_vpVerify.timestamp_grant_permission == 0, "RR82");
        require((block.timestamp - _vpVerify.timestamp_provide_consent) <= timelimit, "RR8");
        verifyVP[_verificationTaskID].timestamp_grant_permission = block.timestamp;
        accessControl[_vpVerify.tokenID][_vpVerify.vfAddr] = true;
    }

    /**
    Caller: Verifier
    When: If the citizen does not grant access permission within timeout even after receiving 
          positive consent from the verifier, verifier can withdraw the locked money. Here, the system
          penalizes the citizen by deducting its locked amount.
    Previous Function: provideConsent() by VF (IDEAL Case: grantAccessPermission() by C)
    **/
    function quit3ByVF(uint256 _verificationTaskID) external
    {
        require(_verificationTaskID >0 && _verificationTaskID <= verificationTaskIDGenerator,"RR72");
        VerificationOfVP memory _vpVerify = verifyVP[_verificationTaskID];
        require(_vpVerify.vfAddr == msg.sender, "RR73");
        require(_vpVerify.timestamp_unlock_money == 0, "RR74");
        require(verificationProtocolCurrentlyRuns[_vpVerify.tokenID][_vpVerify.vfAddr] == true, "RR70");
        require(_vpVerify.timestamp_provide_consent != 0, "RR83");
        require(_vpVerify.consent == true, "RR84");
        require(_vpVerify.timestamp_grant_permission == 0 && (block.timestamp - _vpVerify.timestamp_provide_consent) > timelimit, "RR76");
        payable(msg.sender).transfer(2*lockingAmount);
        _vpVerify.timestamp_unlock_money = block.timestamp;
        verifyVP[_verificationTaskID] = _vpVerify;
        verificationProtocolCurrentlyRuns[_vpVerify.tokenID][_vpVerify.vfAddr] = false;
    }

    /**
    Caller: Verifier
    When: Once the citizen grants permission, next the verifier fetches useful information about 
          the vaccine passport. It's not a transaction, rather  a view function
    Previous Function: grantPermissionAndLockMoney() by citizen
    **/
    function fetchVPInfo(uint256 _verificationTaskID) external view returns(string memory, bytes32, string memory)
    {
        require(_verificationTaskID >0 && _verificationTaskID <= verificationTaskIDGenerator,"RR72");
        VerificationOfVP memory _vpVerify = verifyVP[_verificationTaskID];
        require(_vpVerify.vfAddr == msg.sender,"RR73");
        uint256 _tokenID = _vpVerify.tokenID;   
        require(_vpVerify.timestamp_unlock_money == 0, "RR74");
        require(verificationProtocolCurrentlyRuns[_tokenID][msg.sender] == true, "RR70");
        require(_vpVerify.timestamp_grant_permission != 0, "RR85");
        require(accessControl[_tokenID][msg.sender] == true, "RR86");
        require(_vpVerify.timestamp_verification_result == 0, "RR87");
        require( (block.timestamp - _vpVerify.timestamp_grant_permission) <= timelimit, "RR8");
        string memory _cID;
        bytes32 _MD_VP;
        string memory _sign_of_VC_on_MD_VP;
        (_cID, _MD_VP, _sign_of_VC_on_MD_VP, ) = instance_SC_C_Govt_1.getVaccinePassport(_tokenID);
        return(_cID, _MD_VP, _sign_of_VC_on_MD_VP); 
    }

    /**
    Caller: Verifier
    When: Finally, the verifier retrieves the citizen's VP and validates the fields,matches with
          the stored hash of VP, verifies the issuer's signature and then  decide on the validity
          of vaccine passport.
    Previous Function: fetchVPInfo() by verifier
    **/
    function verificationResult(uint256 _verificationTaskID, bool _result) external
    {
        require(_verificationTaskID >0 && _verificationTaskID <= verificationTaskIDGenerator,"RR72");
        VerificationOfVP memory _vpVerify = verifyVP[_verificationTaskID];
        require(_vpVerify.vfAddr == msg.sender,"RR73");
        uint256 _tokenID = _vpVerify.tokenID;
        require(_vpVerify.timestamp_unlock_money == 0, "RR74");
        require(verificationProtocolCurrentlyRuns[_tokenID][msg.sender] == true, "RR70");
        require(_vpVerify.timestamp_verification_result == 0, "RR87");
        require( (block.timestamp - _vpVerify.timestamp_grant_permission) <= timelimit, "RR8");
        _vpVerify.timestamp_verification_result = block.timestamp;
        _vpVerify.isValidVP = _result;
        payable(msg.sender).transfer(lockingAmount);
        payable(_vpVerify.cAddr).transfer(lockingAmount);
        /**
        bool _vaccination_status;
        bool _vp_status;
        (,,_vaccination_status, _vp_status) = instance_SC_C_Govt_1.getCitizen(_tokenID);
        if(_vaccination_status == false || _vp_status == false)
        {
            _vpVerify.isValidVP = false;
            payable(msg.sender).transfer(2*lockingAmount); //Penalize citizen by deducting its locked amount, as s/he not took vaccination yet or got VP!! 
        }
        else
        {
            _vpVerify.isValidVP = _result;
            payable(msg.sender).transfer(lockingAmount);
            payable(_vpVerify.cAddr).transfer(lockingAmount);
        }
        **/
        _vpVerify.timestamp_unlock_money = block.timestamp;
        verifyVP[_verificationTaskID] = _vpVerify;
        verificationProtocolCurrentlyRuns[_tokenID][msg.sender] = false;
    }

    /**
    Caller: Citizen
    When: Fetching vp details, if the verifier does not provide the verification result within timeout, 
          the citizen can quit the protocol and unlock it's money. Here, the system will penalize the verfier 
          by deducting it's locked amount.
    Previous Function: grantAccessPermission() by C (IDEAL Case: fetchVPInfo() by VF)
    **/
    function quit4ByC(uint256 _verificationTaskID) external
    {
        require(_verificationTaskID >0 && _verificationTaskID <= verificationTaskIDGenerator,"RR72");
        VerificationOfVP memory _vpVerify = verifyVP[_verificationTaskID];
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        require(_vpVerify.tokenID == _tokenID, "RR73");
        require(_vpVerify.timestamp_unlock_money == 0, "RR74");
        require(verificationProtocolCurrentlyRuns[_vpVerify.tokenID][_vpVerify.vfAddr] == true, "RR70");
        require(_vpVerify.timestamp_grant_permission != 0, "RR85");
        require(_vpVerify.timestamp_verification_result == 0 && (block.timestamp - _vpVerify.timestamp_grant_permission) > timelimit, "RR76");
        payable(msg.sender).transfer(2*lockingAmount);
        _vpVerify.timestamp_unlock_money = block.timestamp;
        verifyVP[_verificationTaskID] = _vpVerify;
        verificationProtocolCurrentlyRuns[_vpVerify.tokenID][_vpVerify.vfAddr] = false;
    }

    /**
    Caller: Citizen
    When: Anytime, if the citizen wants to revoke access permission from a verfier, to whom the access
          was granted earlier, citizen can invoke this function.
    Previous Function: No dependency.
    **/
    function revokePermission(address _vfAddr) external 
    {
        uint256 _tokenID = instance_SC_C_Govt_1.getTokenID(msg.sender);
        require( _tokenID != 0,"RR61");
        require(accessControl[_tokenID][_vfAddr] == true, "RR88");
        accessControl[_tokenID][_vfAddr] = false;
    }
}
