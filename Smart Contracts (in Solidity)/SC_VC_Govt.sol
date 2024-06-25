// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract SC_VC_Govt
{
    address public govt;

    struct VCRegistrationAppl
    {
        //uint256 no_of_times_applied;
        uint256 timestamp_reg_appl; //populated by VC
        bytes32 hash_of_reg_appl; //populated by Govt
        uint256 timestamp_hash_reg_appl; //populated by Govt
        bool acceptance_of_reg_appl_hash; //populated by VC
        uint256 timestamp_acceptance_reg_appl_hash; //populated by VC
        bool acceptance_of_reg_appl; //populated by Govt
        uint256 timestamp_acceptance_reg_appl; //populated by Govt
        uint256 applID;
    }

    struct VC //Vaccination Center
    {
        uint256 vcID;
        uint256 currentStockID;
        uint256 no_of_vaccine_vials_remaining;
        uint256 money_earned;
    }

    struct RefillVaccineStockAppl
    {
        uint256 timestamp_refill_Appl; //populated by VC
        uint256 cardinality_of_set; //populated by Govt
        bytes32 commitment_vaccine_set; //populated by Govt
        uint256 timestamp_commit_vaccine_set; //populated by Govt
        bool accept_vaccine_set; //populated by VC
        uint256 timestamp_accept_vaccine_set; //populated by VC
    }

    struct VaccineStock
    {
        uint256 stockID;
        uint256 timestamp_stock; //When VC receives the Stock
        uint256 no_of_vaccine_vials_supplied;
        bytes32 stock_MR;
    }

    //Declaration of Mapping Data Stricture..
    mapping(address=>mapping(uint256=>VCRegistrationAppl)) public vcRegistrationAppl;
    mapping(address=>uint256) public latestVCRegistrationApplNumber;
    mapping(address=>bool) public vcRegistrationApplUnderProcess;
    mapping(uint256=>address) public vcRegistrationApplBelongsTo;

    mapping(address=>uint256) public vcAddrTovcID;
    mapping(uint256=>address) public vcIDTovcAddr;
    mapping(uint256=>VC) public getVCFromvcID;

    mapping(uint256=>mapping(uint256=>RefillVaccineStockAppl)) public refillVaccineAppl;
    mapping(uint256=>uint256) public latestVCRefillApplNumber;
    mapping(uint256=>uint256) public vcRefillApplBelongsTo; //Maps: Refill Apll ID -> vcID
    mapping(uint256=>bool) public vcRefillApplUnderProcess;
    mapping(uint256=>uint256) public vaccineStockBelongsTo; //Maps: stockID -> vcID
    mapping(uint256=>VaccineStock) public vaccineStockDetails; //Maps: stockID -> struct VaccineStock
    mapping(uint256=>uint256) public lockedServiceChargeForVC; //Maps: vcID -> locked amount
    mapping(uint256=>uint256) public amountToBeRefundedToGovt; //Maps: vcID -> refund amount for Govt

    enum VialState{ UNUSED, SPENT , UNDER_PROTOCOL_EXECUTION }
    mapping(bytes32=>VialState) public vialState; //Maps: hash of vialID -> VialState

    uint256 public constant timeLimit = 300 seconds;
    uint256 public constant perVaccineServiceCharge = 1000 wei;
    uint256 public regApplIDGenerator = 0;
    uint256 public refillApplIDGenerator = 0;
    uint256 public vcIDGenerator = 0;
    uint256 public stockIDGenerator = 0;


    constructor() 
    {
      govt = msg.sender;
    }

    modifier onlyGovt(address _party)
    {
        require(_party == govt, "RR1");
        _;
    }

    modifier otherThanGovt(address _party)
    {
        require(_party != govt, "RR2");
        _;
    }

    
     //Interface for other contracts..
    function getGovt() external view returns(address)
    {
        return(govt);
    }

    function getvcID(address _vcAddr) external view returns(uint256)
    {
        return(vcAddrTovcID[_vcAddr]);
    }

    function getvcAddr(uint256 _vcID) external view returns(address)
    {
        return(vcIDTovcAddr[_vcID]);
    }

    function getVC(uint256 _vcID) external view returns(uint256,uint256,uint256,uint256)
    {
        VC memory vc = getVCFromvcID[_vcID];
        return(vc.vcID,vc.currentStockID,vc.no_of_vaccine_vials_remaining,vc.money_earned);
    }

    function isValidVC(uint256 _vcID) external view returns(bool)
    {
        if(_vcID>0 && _vcID<=vcIDGenerator)
        {
            return(true);
        }
        else
        {
            return(false);
        }
    }

    function getVialState(bytes32 _vialHash) external view returns(uint8)
    {
        return(uint8(vialState[_vialHash]));
    }

    function setVialState(bytes32 _vialHash, uint8 _state) external
    {
        require(_state <= uint8(VialState.UNDER_PROTOCOL_EXECUTION), "");
        vialState[_vialHash] = VialState(_state);
    }

    function getStockInfo(uint256 _stockID) external view returns(uint256, uint256, uint256, bytes32)
    {
        VaccineStock memory v = vaccineStockDetails[_stockID];
        return(v.stockID,v.timestamp_stock,v.no_of_vaccine_vials_supplied,v.stock_MR);
    }

    function serviceChargeAmount() external pure returns(uint256)
    {
        return(perVaccineServiceCharge);
    }

    function payServiceCharge(address _vcAddr) external 
    {
        payable(_vcAddr).transfer(perVaccineServiceCharge);
        uint256 _vcID = vcAddrTovcID[_vcAddr];
        VC memory vc = getVCFromvcID[_vcID];
        vc.money_earned += perVaccineServiceCharge;
        vc.no_of_vaccine_vials_remaining -= 1;
        getVCFromvcID[_vcID] = vc;
        lockedServiceChargeForVC[_vcID] -= perVaccineServiceCharge;
    }

    //-----------------------------------------------------------------------
    //VC Regsitration..
    function timestampAppl() external otherThanGovt(msg.sender) //Caller: VC
    {
        uint256 lastApplNo = latestVCRegistrationApplNumber[msg.sender];
        VCRegistrationAppl memory x = vcRegistrationAppl[msg.sender][lastApplNo];
        require(vcAddrTovcID[msg.sender] == 0, "RR3");
        if(vcRegistrationApplUnderProcess[msg.sender] == true)
        {
            //VC-->applied, Then Govt-->did not respond with appl hash at all (or, within time limit)
            if(x.timestamp_reg_appl != 0 && x.timestamp_hash_reg_appl == 0 && (block.timestamp - x.timestamp_reg_appl) > timeLimit)
            {
                vcRegistrationApplUnderProcess[msg.sender] = false;
            }
            //VC-->applied, Govt-->responded with hash, Then VC-->did not provide consent at all (or within time limit).
            if(x.timestamp_reg_appl != 0 && x.timestamp_hash_reg_appl != 0 && x.timestamp_acceptance_reg_appl_hash == 0 && (block.timestamp - x.timestamp_hash_reg_appl) > timeLimit)
            {
                vcRegistrationApplUnderProcess[msg.sender] = false;
            }
            //VC-->applied, Govt-->responded with hash, VC-->agreed with hash, Then Govt-->did not provide acceptance decision of appl at all (or within time limit).
            if(x.timestamp_reg_appl != 0 && x.timestamp_hash_reg_appl != 0 && x.timestamp_acceptance_reg_appl_hash != 0 && x.timestamp_acceptance_reg_appl == 0 && (block.timestamp - x.timestamp_acceptance_reg_appl_hash) > timeLimit)
            {
                vcRegistrationApplUnderProcess[msg.sender] = false;
            }
        }
        require(vcRegistrationApplUnderProcess[msg.sender] == false, "RR4"); 
        lastApplNo += 1;
        VCRegistrationAppl memory y = vcRegistrationAppl[msg.sender][lastApplNo];
        //x.no_of_times_applied += 1;
        y.timestamp_reg_appl = block.timestamp;
        vcRegistrationAppl[msg.sender][lastApplNo] = y;
        vcRegistrationApplUnderProcess[msg.sender] = true;
        latestVCRegistrationApplNumber[msg.sender] = lastApplNo;
    }


    function applHash(address _vcAddr, bytes32 _hash_of_appl) external onlyGovt(msg.sender) //Caller: Govt
    {
        uint256 lastApplNo = latestVCRegistrationApplNumber[_vcAddr];
        VCRegistrationAppl memory x = vcRegistrationAppl[_vcAddr][lastApplNo];
        require(vcAddrTovcID[_vcAddr] == 0, "RR3");
        require(vcRegistrationApplUnderProcess[_vcAddr] == true, "RR5");
        require(x.timestamp_reg_appl != 0, "RR6");
        require(x.timestamp_hash_reg_appl == 0,"RR7");
        require((block.timestamp - x.timestamp_reg_appl) <= timeLimit, "RR8");
        x.hash_of_reg_appl = _hash_of_appl;
        x.timestamp_hash_reg_appl = block.timestamp;
        vcRegistrationAppl[_vcAddr][lastApplNo] = x;
    }

    function decideOnAcceptanceHash(bool _decision) external otherThanGovt(msg.sender) //Caller: VC
    {
        uint256 lastApplNo = latestVCRegistrationApplNumber[msg.sender];
        VCRegistrationAppl memory x = vcRegistrationAppl[msg.sender][lastApplNo];
        require(vcAddrTovcID[msg.sender] == 0, "RR3");
        require(vcRegistrationApplUnderProcess[msg.sender] == true, "RR5");
        require(x.timestamp_hash_reg_appl != 0,"RR9");
        require(x.timestamp_acceptance_reg_appl_hash == 0,"RR10");
        require((block.timestamp - x.timestamp_hash_reg_appl) <= timeLimit, "RR8");
        x.acceptance_of_reg_appl_hash = _decision;
        x.timestamp_acceptance_reg_appl_hash = block.timestamp;
        if(_decision == true)
        {
            //Generate Application ID..
            regApplIDGenerator += 1;
            x.applID = regApplIDGenerator;
        }
        else
        {
            vcRegistrationApplUnderProcess[msg.sender] = false; // So that VC can resubmit application.
        }
        vcRegistrationAppl[msg.sender][lastApplNo] = x;
        vcRegistrationApplBelongsTo[regApplIDGenerator] = msg.sender;
    }

    function decideOnAcceptanceAppl(uint256 _applID, bool _decision) external onlyGovt(msg.sender) //Caller: Govt
    {
        address _vcAddr = vcRegistrationApplBelongsTo[_applID];
        require(_vcAddr != 0x0000000000000000000000000000000000000000,"RR11");
        require(vcAddrTovcID[_vcAddr] == 0, "RR3");
        require(vcRegistrationApplUnderProcess[_vcAddr] == true, "RR5");
        uint256 lastApplNo = latestVCRegistrationApplNumber[_vcAddr];
        VCRegistrationAppl memory x = vcRegistrationAppl[_vcAddr][lastApplNo];
        require(x.timestamp_acceptance_reg_appl_hash != 0, "RR12");
        require(x.timestamp_acceptance_reg_appl == 0, "RR13");
        require((block.timestamp - x.timestamp_acceptance_reg_appl_hash) <= timeLimit, "RR8");
        x.acceptance_of_reg_appl = _decision;
        x.timestamp_acceptance_reg_appl = block.timestamp;
        if(_decision == true)
        {
            //Generate vcID;
            vcIDGenerator += 1;
            vcAddrTovcID[_vcAddr] = vcIDGenerator;
            vcIDTovcAddr[vcIDGenerator] = _vcAddr;
            getVCFromvcID[vcIDGenerator] = VC(vcIDGenerator,0,0,0); //Populate a new VC struct and assign to the map.
        }
        vcRegistrationAppl[_vcAddr][lastApplNo] = x;
        vcRegistrationApplUnderProcess[_vcAddr] = false;
    }

    //Before Disbursement of Vaccine Vials..
    function refillStockAppl() external otherThanGovt(msg.sender) //caller VC
    {
        uint256 _vcID = vcAddrTovcID[msg.sender];
        require(_vcID != 0, "RR14");
        VC memory vc = getVCFromvcID[_vcID];
        require(vc.no_of_vaccine_vials_remaining == 0, "RR15");
        uint256 lastRefillApplNo = latestVCRefillApplNumber[_vcID];
        RefillVaccineStockAppl memory x = refillVaccineAppl[_vcID][lastRefillApplNo];
        if(vcRefillApplUnderProcess[_vcID] == true)
        {
            //Govt didn't commit vaccine set within time limit after the last refill application was made.
            if((block.timestamp - x.timestamp_refill_Appl)>timeLimit && x.timestamp_commit_vaccine_set == 0)
            {
                vcRefillApplUnderProcess[_vcID] = false;
            }
            //VC didn't respond within time limit after Govt's commitment.
            if(x.timestamp_commit_vaccine_set != 0 && (block.timestamp - x.timestamp_commit_vaccine_set)>timeLimit && x.timestamp_accept_vaccine_set==0)
            {
                vcRefillApplUnderProcess[_vcID] = false;
                amountToBeRefundedToGovt[_vcID] += x.cardinality_of_set*perVaccineServiceCharge;
                lockedServiceChargeForVC[_vcID] -= x.cardinality_of_set*perVaccineServiceCharge;
            }
        }
        require(vcRefillApplUnderProcess[_vcID] == false, "RR16");
        //Generate a new application for Refilling Vaccine Stock.
        refillApplIDGenerator += 1;
        RefillVaccineStockAppl memory y = refillVaccineAppl[_vcID][refillApplIDGenerator];
        y.timestamp_refill_Appl = block.timestamp;
        refillVaccineAppl[_vcID][refillApplIDGenerator] = y;
        vcRefillApplBelongsTo[refillApplIDGenerator] = _vcID;
        latestVCRefillApplNumber[_vcID] = refillApplIDGenerator;
        vcRefillApplUnderProcess[_vcID] = true;
    }

    function commitVaccineSet(uint256 _cardinality, bytes32 _MR, uint256 _vcID) external payable onlyGovt(msg.sender) //Caller: Govt
    {
        require(_vcID > 0 && _vcID <= vcIDGenerator, "RR17");
        require(_cardinality != 0,"RR18");
        require(vcRefillApplUnderProcess[_vcID] == true, "RR19");
        VC memory vc = getVCFromvcID[_vcID];
        require(vc.no_of_vaccine_vials_remaining == 0, "RR15");
        uint256 lastRefillApplNo = latestVCRefillApplNumber[_vcID];
        RefillVaccineStockAppl memory x = refillVaccineAppl[_vcID][lastRefillApplNo];
        require(x.timestamp_commit_vaccine_set == 0, "RR21");
        require((block.timestamp - x.timestamp_refill_Appl) <= timeLimit, "RR8");
        require(msg.value == _cardinality*perVaccineServiceCharge,"RR22");
        lockedServiceChargeForVC[_vcID] = msg.value;
        x.cardinality_of_set = _cardinality;
        x.commitment_vaccine_set = _MR;
        x.timestamp_commit_vaccine_set = block.timestamp;
        refillVaccineAppl[_vcID][lastRefillApplNo] = x;
    }

    function decideOnAcceptanceVaccineSet(bool _decision) external otherThanGovt(msg.sender) //Caller: VC
    {
        uint256 _vcID = vcAddrTovcID[msg.sender];
        require(_vcID != 0, "RR14");
        VC memory vc = getVCFromvcID[_vcID];
        require(vc.no_of_vaccine_vials_remaining == 0,"RR15");
        uint256 lastRefillApplNo = latestVCRefillApplNumber[_vcID];
        require(lastRefillApplNo != 0, "RR19");
        RefillVaccineStockAppl memory x = refillVaccineAppl[_vcID][lastRefillApplNo];
        require(vcRefillApplUnderProcess[_vcID] == true,"RR19");
        require(x.timestamp_accept_vaccine_set == 0,"RR20");
        require((block.timestamp - x.timestamp_commit_vaccine_set) <= timeLimit,"RR8");
        require(lockedServiceChargeForVC[_vcID] == x.cardinality_of_set*perVaccineServiceCharge, "RR23");
        //Write code for refund to Govt if decision is false..
        if(_decision == true)
        {
            //Create a new Stock.
            stockIDGenerator += 1;
            vaccineStockBelongsTo[stockIDGenerator] = _vcID;
            vaccineStockDetails[stockIDGenerator] = VaccineStock(stockIDGenerator,block.timestamp,x.cardinality_of_set,x.commitment_vaccine_set);
            vc.currentStockID = stockIDGenerator;
            vc.no_of_vaccine_vials_remaining = x.cardinality_of_set;
            getVCFromvcID[_vcID] = vc;
        }
        else
        {
            amountToBeRefundedToGovt[_vcID] += x.cardinality_of_set*perVaccineServiceCharge;
            lockedServiceChargeForVC[_vcID] -= x.cardinality_of_set*perVaccineServiceCharge;
        }
        x.accept_vaccine_set = _decision;
        x.timestamp_accept_vaccine_set = block.timestamp;
        refillVaccineAppl[_vcID][lastRefillApplNo] = x;
        vcRefillApplUnderProcess[_vcID] = false;
    }

    function takeAwayLockedMoney(uint _vcID) external onlyGovt(msg.sender)
    {
        require(_vcID>0 && _vcID<=vcIDGenerator,"RR17");
        //require(vcRefillApplUnderProcess[_vcID] == true, "Govt can't take away locked money at this moment. No active refill application found for this VC!!");
        uint256 lastRefillApplNo = latestVCRefillApplNumber[_vcID];
        require(lastRefillApplNo != 0, "RR24");
        RefillVaccineStockAppl memory x = refillVaccineAppl[_vcID][lastRefillApplNo];
        //VC didn't responded within timelimit after Govt's commitment..
        if(x.timestamp_commit_vaccine_set != 0 && (block.timestamp - x.timestamp_commit_vaccine_set)>timeLimit && vcRefillApplUnderProcess[_vcID] == true && x.timestamp_accept_vaccine_set == 0)
        {
            amountToBeRefundedToGovt[_vcID] += x.cardinality_of_set*perVaccineServiceCharge;
            lockedServiceChargeForVC[_vcID] -= x.cardinality_of_set*perVaccineServiceCharge;
            vcRefillApplUnderProcess[_vcID] = false;
        }
        require(amountToBeRefundedToGovt[_vcID] != 0,"RR25");
        payable(govt).transfer(amountToBeRefundedToGovt[_vcID]);
        amountToBeRefundedToGovt[_vcID] = 0;       
    }
        
    function getBalance() external view returns(uint256) 
    {
        return address(this).balance;
    }

}