// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
import "./SC_VC_Govt.sol";

contract SC_C_Govt_1
{
    address addr_SC_VC_Govt;
    SC_VC_Govt instance_SC_VC_Govt;

    struct ApplForObtainingTokenID
    {
        address applicant_addr; //msg.sender
        bytes32 commit_citizen_info; //Populated by Citizen.
        uint256 timestamp_token_appl; //Populated by Citizen.
        uint256 token_appl_number; //SC generates application number.
        uint256 timestamp_token_appl_verification; //populated by Govt.
        bool token_appl_verification_result;
    }

    struct VaccinePassport
    {
        string cID; // content identifier in IPFS of citizen's VP.
        bytes32 message_digest_vp;
        string sig_on_message_digest_vp;  
        uint256 timestamp_create_vp;
    }
    
    struct Citizen
    {
        bytes32 citizen_info_digest;
        uint256 tokenID;
        bool vaccination_status;
        bool vaccine_passport_issued;
        VaccinePassport vp;
    }

    mapping(address=>uint256) public latestTokenApplNumber; //Maps: citizen address to token_appl_number.
    mapping(uint256=>bool) public citizenTokenApplUnderProcess; //Maps: token_appl_number to boolean value
    mapping(uint256=>ApplForObtainingTokenID) public citizenTokenAppl; //Maps: token_appl_number to structure data.
    
    mapping(address=>bytes32) public citizenAddrToCitizenHash;
    mapping(bytes32=>uint256) public citizenHashToTokenID;
    mapping(uint256=>Citizen) public tokenIDToCitizenDetails;

    uint256 public tokenApplNumberGenerator = 0;
    uint256 public tokenIDGenerator = 0; 
    uint256 public constant timeLimit = 300 seconds;


    constructor(address _addr_SC_VC_Govt) 
    {
        addr_SC_VC_Govt = _addr_SC_VC_Govt;
        instance_SC_VC_Govt = SC_VC_Govt(addr_SC_VC_Govt);
    }

    modifier onlyGovt(address _party)
    {
        require(_party == instance_SC_VC_Govt.getGovt(), "RR1");
        _;
    }

    modifier onlyCitizen(address _party)
    {
        //citizen can't be Govt.
        require(_party != instance_SC_VC_Govt.getGovt(), "RR26");
        //citizen can't be VC.
        require(instance_SC_VC_Govt.getvcID(_party) == 0, "RR27");
        _;
    }

    //Interfaces for Other Contracts.
    function getTokenID(address _cAddr) external view returns(uint256)
    {
        return(citizenHashToTokenID[citizenAddrToCitizenHash[_cAddr]]);
    }

    function getCitizen(uint256 _tokenID) external view returns(bytes32, uint256, bool, bool)
    {
        Citizen memory c = tokenIDToCitizenDetails[_tokenID];
        return(c.citizen_info_digest, c.tokenID, c.vaccination_status, c.vaccine_passport_issued);
    }

    function getVaccinePassport(uint256 _tokenID) external view returns(string memory, bytes32, string memory, uint256)
    {
        Citizen memory c = tokenIDToCitizenDetails[_tokenID];
        return(c.vp.cID, c.vp.message_digest_vp, c.vp.sig_on_message_digest_vp, c.vp.timestamp_create_vp);
    }

    function setVaccinationStatus(uint256 _tokenID) external
    {
        Citizen memory c = tokenIDToCitizenDetails[_tokenID];
        c.vaccination_status = true;
        c.vaccine_passport_issued = false;
        tokenIDToCitizenDetails[_tokenID] = c;
    }

    function issueVaccinePassport(uint256 _tokenID, string memory _cID, bytes32 _message_digest_vp, string memory _sig_on_message_digest_vp, uint256 _timestamp_create_vp) external
    {
        Citizen memory c = tokenIDToCitizenDetails[_tokenID];
        c.vaccine_passport_issued = true;
        c.vp = VaccinePassport(_cID, _message_digest_vp, _sig_on_message_digest_vp, _timestamp_create_vp);
        tokenIDToCitizenDetails[_tokenID] = c;
    }
    /**************************************/
    function applForTokenID(bytes32 _commit_citizen_info) external onlyCitizen(msg.sender)
    {
        require(citizenHashToTokenID[citizenAddrToCitizenHash[msg.sender]] == 0, "RR68");
        require(citizenHashToTokenID[_commit_citizen_info] == 0,"RR28");
        uint256 _tokenApplNo = latestTokenApplNumber[msg.sender];
        if(citizenTokenApplUnderProcess[_tokenApplNo] == true)
        {
            ApplForObtainingTokenID memory x = citizenTokenAppl[_tokenApplNo];
            if( x.timestamp_token_appl != 0 && x.timestamp_token_appl_verification == 0 && (block.timestamp - x.timestamp_token_appl) > timeLimit) //Govt didn't respond within time limit.
            {
                citizenTokenApplUnderProcess[_tokenApplNo] = false;
            }
        }
        require(citizenTokenApplUnderProcess[_tokenApplNo] == false,"RR29");
        //Generate a new application..
        tokenApplNumberGenerator += 1;
        ApplForObtainingTokenID memory y = citizenTokenAppl[tokenApplNumberGenerator];
        y.applicant_addr = msg.sender;
        y.commit_citizen_info = _commit_citizen_info;
        y.timestamp_token_appl = block.timestamp;
        y.token_appl_number = tokenApplNumberGenerator;
        citizenTokenAppl[tokenApplNumberGenerator] = y;
        latestTokenApplNumber[msg.sender] = tokenApplNumberGenerator;
        citizenTokenApplUnderProcess[tokenApplNumberGenerator] = true;
    }

    function verifyTokenAppl(address _applicant_addr, bool _decision) external onlyGovt(msg.sender)
    {
        uint256 _tokenApplNo = latestTokenApplNumber[_applicant_addr];
        require(_tokenApplNo != 0, "RR30");
        require(citizenTokenApplUnderProcess[_tokenApplNo] == true,"RR31");
        ApplForObtainingTokenID memory x = citizenTokenAppl[_tokenApplNo];
        require(x.timestamp_token_appl_verification == 0,"RR21");
        require((block.timestamp - x.timestamp_token_appl) <= timeLimit,"RR8");
        require(x.applicant_addr == _applicant_addr,"RR32");
        //x.hash_of_citizen_info = _hash_of_citizen_info;
        x.timestamp_token_appl_verification = block.timestamp;
        if(_decision == true)
        {
            x.token_appl_verification_result = true;
            //generate Token ID..
            tokenIDGenerator += 1;
            citizenHashToTokenID[x.commit_citizen_info] = tokenIDGenerator;
            tokenIDToCitizenDetails[tokenIDGenerator] = Citizen(x.commit_citizen_info,tokenIDGenerator,false,false,VaccinePassport("",bytes32(0),"",0));
            citizenAddrToCitizenHash[x.applicant_addr] = x.commit_citizen_info;
        }
        else
        {
            x.token_appl_verification_result = false;
        }
        citizenTokenAppl[_tokenApplNo] = x;
        citizenTokenApplUnderProcess[_tokenApplNo] = false;
    }
}