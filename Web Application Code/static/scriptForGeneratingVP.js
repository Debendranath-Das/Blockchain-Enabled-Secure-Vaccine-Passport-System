function computeCrypto() {
    const priKey_VC = document.getElementById("privateKeyVC");
    const pubKey_C = document.getElementById("publicKeyC");
}
function returnBack() {
    document.getElementById("decideOnVP").style.display = "block";
    document.getElementById("divCrypto").style.display = "none";
}
function proceed() {
    document.getElementById("decideOnVP").style.display = "none";
    document.getElementById("divCrypto").style.display = "block";
}
function goBack() {
    document.getElementById("vpForm").style.display = "block";
    document.getElementById("output").style.display = "none";
    window.location.reload();
}
function fetchCurrentTimestamp() {
    var now = new Date();
    var day = now.getDate().toString().padStart(2, '0');
    var month = (now.getMonth() + 1).toString().padStart(2, '0');
    var year = now.getFullYear().toString();
    var hours = now.getHours().toString().padStart(2, '0');
    var minutes = now.getMinutes().toString().padStart(2, '0');
    var seconds = now.getSeconds().toString().padStart(2, '0');
    var formattedDateTime = day + '.' + month + '.' + year + ' ' + hours + ':' + minutes + ':' + seconds;
    document.getElementById("timestampOfVPGeneration").value = formattedDateTime;
}
window.onload = fetchCurrentTimestamp;

function resetForm() {
    //document.getElementById("jsonOutput").innerHTML = "";
    document.getElementById("error_citizenAddr").innerHTML = "";
    document.getElementById("error_hashOfCitizenInfo").innerHTML = "";
    document.getElementById("error_issuerVaccinationCenterAddr").innerHTML = "";
    document.getElementById("error_issuerVaccinationCenterID").innerHTML = "";
    document.getElementById("error_vaccineVialID").innerHTML = "";
    document.getElementById("error_stockID").innerHTML = "";
    window.location.reload();
}

function createJSON(citizenAddr, hashOfCitizenInfo, targatedDisease, countryOfVaccination, timestampOfVPGeneration, issuerVaccinationCenterAddr, issuerVaccinationCenterID, vaccineName, vaccineVialID, stockID) {
    // Create JSON object
    console.log(citizenAddr);
    var vaccinePassport =
    {
        "Citizen Ethereum Address": citizenAddr,
        "Hash of Citizen Personal Info": hashOfCitizenInfo,
        "Disease Targeted": targatedDisease,
        "Country of Vaccination": countryOfVaccination,
        "Timestamp of Vaccination": timestampOfVPGeneration,
        "Issuer Vaccination Center Ethereum Address": issuerVaccinationCenterAddr,
        "Issuer Vaccination Center ID": issuerVaccinationCenterID,
        "Vaccine Name": vaccineName,
        "Vaccine Vial ID": vaccineVialID,
        "Stock ID": stockID
    };

    console.log(vaccinePassport);
    // Convert JSON object to string
    //var json = JSON.stringify(vaccinePassport);
    var json = '';

    for (var key in vaccinePassport) {
        if (vaccinePassport.hasOwnProperty(key)) {
            json += key + ': ' + vaccinePassport[key] + '\n';
        }
    }

    // Display JSON object on the page
    document.getElementById("jsonOutput").innerHTML = json;
}

const myForm = document.getElementById("vpForm");

myForm.addEventListener("submit", function (event) {
    event.preventDefault();

    const citizenAddr = document.getElementById("citizenAddr");
    const hashOfCitizenInfo = document.getElementById("hashOfCitizenInfo");
    const targatedDisease = document.getElementById("targatedDisease");
    const countryOfVaccination = document.getElementById("countryOfVaccination");
    const timestampOfVPGeneration = document.getElementById("timestampOfVPGeneration");
    const issuerVaccinationCenterAddr = document.getElementById("issuerVaccinationCenterAddr");
    const issuerVaccinationCenterID = document.getElementById("issuerVaccinationCenterID");
    const vaccineName = document.getElementById("vaccineName");
    const vaccineVialID = document.getElementById("vaccineVialID");
    const stockID = document.getElementById("stockID");

    if (!validateAddr(citizenAddr.value.trim())) {
        document.getElementById("error_citizenAddr").innerHTML = "Invalid citizen address!! Please enter the valid address.";
        citizenAddr.classList.add("error");
    }
    else {
        document.getElementById("error_citizenAddr").innerHTML = "";
        citizenAddr.classList.remove("error");
    }

    if (!validateHashOfCitizenInfo(hashOfCitizenInfo.value.trim())) {
        document.getElementById("error_hashOfCitizenInfo").innerHTML = "Invalid hash value!! Please enter the valid hash value.";
        hashOfCitizenInfo.classList.add("error");
    }
    else {
        document.getElementById("error_hashOfCitizenInfo").innerHTML = "";
        hashOfCitizenInfo.classList.remove("error");
    }

    if (!validateAddr(issuerVaccinationCenterAddr.value.trim())) {
        document.getElementById("error_issuerVaccinationCenterAddr").innerHTML = "Invalid VC Address!! Please enter the valid VC address.";
        issuerVaccinationCenterAddr.classList.add("error");
    }
    else {
        document.getElementById("error_issuerVaccinationCenterAddr").innerHTML = "";
        issuerVaccinationCenterAddr.classList.remove("error");
    }

    if (!validateVaccinationCenterID(issuerVaccinationCenterAddr.value.trim(), issuerVaccinationCenterID.value.trim())) {
        document.getElementById("error_issuerVaccinationCenterID").innerHTML = "Invalid VC ID!! Please enter the valid VC ID.";
        issuerVaccinationCenterID.classList.add("error");
    }
    else {
        document.getElementById("error_issuerVaccinationCenterID").innerHTML = "";
        issuerVaccinationCenterID.classList.remove("error");
    }

    if (!validateVaccineVialID(vaccineVialID.value.trim())) {
        document.getElementById("error_vaccineVialID").innerHTML = "Invalid vaccine vial ID!! Please enter the valid vial ID.";
        vaccineVialID.classList.add("error");
    }
    else {
        document.getElementById("error_vaccineVialID").innerHTML = "";
        vaccineVialID.classList.remove("error");
    }

    if (!validateStockID(stockID.value.trim())) {
        document.getElementById("error_stockID").innerHTML = "Invalid stock ID!! Please enter the valid stock ID.";
        stockID.classList.add("error");
    }
    else {
        document.getElementById("error_stockID").innerHTML = "";
        stockID.classList.remove("error");
    }

    // Submit the form if all fields are valid
    if (!citizenAddr.classList.contains("error") && !hashOfCitizenInfo.classList.contains("error") && !issuerVaccinationCenterAddr.classList.contains("error") && !issuerVaccinationCenterID.classList.contains("error") && !vaccineVialID.classList.contains("error") && !stockID.classList.contains("error")) {
        document.getElementById("vpForm").style.display = "none";
        document.getElementById("output").style.display = "block";
        createJSON(citizenAddr.value.trim(), hashOfCitizenInfo.value.trim(), targatedDisease.value, countryOfVaccination.value, timestampOfVPGeneration.value, issuerVaccinationCenterAddr.value.trim(), issuerVaccinationCenterID.value.trim().replace(/^0+/, ''), vaccineName.value, vaccineVialID.value.trim(), stockID.value.trim().replace(/^0+/, ''));
    }
});

function validateAddr(_address) {
    var isValid = true;
    var regx = /^0[x,X][\d,a-f,A-F]{40}$/;
    if (!regx.test(_address)) {
        isValid = false;
    }
    return isValid;
}

function validateHashOfCitizenInfo(_hashVal) {
    var isValid = true;
    var regx = /^0[x,X][\d,a-f,A-F]{64}$/;
    if (!regx.test(_hashVal)) {
        isValid = false;
    }
    return true;
}

function validateVaccinationCenterID(_vcAddr, _vcID) {
    return true;
}

function validateVaccineVialID(_vID) {
    return true;
}

function validateStockID(_stockID) {
    return true;
}