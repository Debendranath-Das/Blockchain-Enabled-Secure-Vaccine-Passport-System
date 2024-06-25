// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
import "./SC_VC_Govt.sol";
import "./SC_C_Govt_1.sol";

contract SC_Requirements_Check
{   
    address addr_SC_VC_Govt;
    SC_VC_Govt instance_SC_VC_Govt;

    address addr_SC_C_Govt_1;
    SC_C_Govt_1 instance_SC_C_Govt_1;

    constructor(address _addr_SC_VC_Govt, address _addr_SC_C_Govt_1) 
    {
        addr_SC_VC_Govt = _addr_SC_VC_Govt;
        instance_SC_VC_Govt = SC_VC_Govt(addr_SC_VC_Govt);
        addr_SC_C_Govt_1 = _addr_SC_C_Govt_1;
        instance_SC_C_Govt_1 = SC_C_Govt_1(addr_SC_C_Govt_1);
    }

    function checkForValidCitizenTokenID(address _party) external view
    {
        //citizen can't be Govt.
        require(_party != instance_SC_VC_Govt.getGovt(), "RR26");
        //citizen can't be VC.
        require(instance_SC_VC_Govt.getvcID(_party) == 0, "RR27");
        //citizen should have a valid tokenID.
        require(instance_SC_C_Govt_1.getTokenID(_party) != 0, "RR61");
    }

    function checkForRegisteredVC(address _party) external view
    {
        require(instance_SC_VC_Govt.isValidVC(instance_SC_VC_Govt.getvcID(_party)) == true, "RR62");
    }

    function checkForRegisteredVC(uint256 _vcID) external view
    {
        require(instance_SC_VC_Govt.isValidVC(_vcID) == true, "RR17");
    }

    function checkForVaccineStock(uint256 _vcID) external view
    {
        uint256 _remainingVials; 
        (,,_remainingVials,) = instance_SC_VC_Govt.getVC(_vcID);
        require(_remainingVials != 0, "RR44");
    }

    function checkForCitizenNotYetVaccinated(uint256 _tokenID) external view
    {
        bool _vaccination_status;
        (,,_vaccination_status,) = instance_SC_C_Govt_1.getCitizen(_tokenID);
        require( _vaccination_status == false, "RR63");
    }
    
    function checkVaccinationAndVPStatusOfCitizen(uint256 _tokenID) external view
    {
        bool _vaccination_status;
        bool _vaccine_passport_issued;
        (, , _vaccination_status, _vaccine_passport_issued) = instance_SC_C_Govt_1.getCitizen(_tokenID);
        require(_vaccination_status == true,"RR97");
        require(_vaccine_passport_issued == false, "RR98");
    }

    function checkForUnusedVaccineVial(bytes32 _vialHash) external view
    { 
        require(instance_SC_VC_Govt.getVialState(_vialHash) == 0, "RR95");
    }

    function checkForSpentVaccineVial(bytes32 _vialHash) external view
    { 
        require(instance_SC_VC_Govt.getVialState(_vialHash) == 1, "RR103");
    }

    function checkForUnderProtocolExecVaccineVial(bytes32 _vialHash) external view
    { 
        require(instance_SC_VC_Govt.getVialState(_vialHash) == 2, "RR96");
    }
}