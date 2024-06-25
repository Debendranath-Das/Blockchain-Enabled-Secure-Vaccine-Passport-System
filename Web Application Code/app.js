const express = require('express');
const path = require('path');
const bodyParser = require('body-parser');
const keccak256 = require('keccak256');
const { MerkleTree } = require('merkletreejs');
const ethUtil = require('ethereumjs-util');
const {Web3} = require('web3');
const Proxy = require("./index").Proxy;
const PRE = require("./index");
const { exec } = require('child_process');
//const fs = require('fs');
//const e = require('express');

/* //Dynamic Import.
import('./ipfs.mjs').then((ipfsModule)=>{
  uploadToIPFS = ipfsModule.uploadToIPFS;
  downloadByCID = ipfsModule.downloadByCID;
}); */

const app = express();
const port = 3001;

/*
  Please change the IP address assigned to your machine and comment the rest before executing the file.
*/

const ipAddr = '192.168.56.204'; //Lab HP Workstation Ubuntu.  
//const ipAddr = '192.168.29.138'; //Hp laptop Windows 11
//const ipAddr = '192.168.29.179'; //Dell Laptop Home Windows
//const ipAddr = '192.168.0.181';  //Laptop in Lab wifi
//const ipAddr = '192.168.56.95'; // Lab Desktop Ubuntu

//Middleware..
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));
app.use(express.static(path.join(__dirname,'static')));
app.use(express.static('static'));

//Initialize web3 object..
const infura_end_point = 'https://sepolia.infura.io/v3/7639bc4f78b246e290057be88121d32c';
const web3 = new Web3(infura_end_point);

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname,'/webpages/Homepage.html'));
});

app.get('/govt', (req,res) => {
  res.sendFile(path.join(__dirname, '/webpages/Govt Helpdesk.html'));
});

app.get('/vaccination_center', (req, res) => {
    res.sendFile(path.join(__dirname,'/webpages/Vaccination Center Helpdesk.html'));
});

app.get('/citizen', (req,res) => {
    res.sendFile(path.join(__dirname,'/webpages/Citizen Helpdesk.html'));
});

app.get('/verifier', (req,res) => {
  res.sendFile(path.join(__dirname,'/webpages/Verifier Helpdesk.html'));
});


app.post('/download_VP', async(req,res) => {
  let { csk, cid } = req.body;
  let error = "";
  if(csk.startsWith("0x") || csk.startsWith("0X"))
  {
    csk = csk.slice(2);
  }
  executeCommand('pgrep ipfs')
    .then((stdout) => {
      console.log('IPFS daemon is running...');
      return Promise.resolve();
    })
    .catch(() => {
      console.log('Please start IPFS daemon first and then fetch the file...');
      return Promise.reject();
    })
    .then(() => {
      return executeCommand(`ipfs cat ${cid}`)
    })
    .then((content) => {
      // Display the content
      let encrypted_VP = JSON.parse(content);
      let decrypted_VP = PRE.decryptData(csk, encrypted_VP);

      const responseData = {
        encrypted_VP: encrypted_VP,
        decrypted_VP: decrypted_VP,
        error: error
      };
      res.json(responseData);
    })
    .catch((error) => {
      if (error) {
        const response = {
          error: error,
          suggestion: "Check Secret key and CID carefully."
        };
        res.json(response);
      }
    });
});

app.post('/get_PK', async(req,res) => {
  let secretKey = req.body.secretKey;
  if(secretKey.startsWith("0x") || secretKey.startsWith("0X"))
  {
    secretKey = secretKey.slice(2);
  }
  let ETH_Addr = derivePublicKeyAndAddress(secretKey).address;
  let pk = derivePublicKeyAndAddress(secretKey).publicKey;

  const responseData = {
    ETH_Addr: ETH_Addr,
    pk: pk
  };
  res.json(responseData);
});

app.post('/decrypt_VP_By_Proxy', async(req,res) => {
  //write code here..
  let { rk, sk, cid } = req.body;
  if(rk.startsWith("0x") || rk.startsWith("0X"))
  {
    rk = rk.slice(2);
  }
  if(sk.startsWith("0x") || sk.startsWith("0X"))
  {
    sk = sk.slice(2);
  }
  let error = "";
  //console.log('RK: ', rk);
  //console.log('SK: ', sk);
  //console.log('CID: ', cid);

  executeCommand('pgrep ipfs')
    .then((stdout) => {
      console.log('IPFS daemon is running...');
      return Promise.resolve();
    })
    .catch(() => {
      console.log('Please start IPFS daemon first and then fetch the file...');
      return Promise.reject();
    })
    .then(() => {
      return executeCommand(`ipfs cat ${cid}`)
    })
    .then((content) => {
      // Display the content
      let encrypted_VP = JSON.parse(content);
      let re_encrypted_VP = PRE.reEncryption(rk, encrypted_VP);
      let decrypted_VP = PRE.decryptData(sk, re_encrypted_VP);

      const responseData = {
        encrypted_VP: encrypted_VP,
        re_encrypted_VP: re_encrypted_VP,
        decrypted_VP: decrypted_VP,
        error: error
      };
      res.json(responseData);
    })
    .catch((error) => {
      if (error) {
        const response = {
          error: error,
          suggestion: "Check Re-encryption key, Verifier's Secret Key and CID carefully."
        }
        res.json(response);
      }
    });
});

app.post('/compute_Hash', (req, res) => {
  const { name, city, dob, aadhaar } = req.body;
  let values = [name,city,dob,aadhaar];
  var concatenatedValues = values.join('');
  var hash = web3.utils.soliditySha3(concatenatedValues);
  const responseData = {
    hash: hash
  };
  res.json(responseData);
});

app.post('/compute_RK', (req, res) => {
  let { pk,sk } = req.body;
  if( pk.startsWith("0x") )
  {
    pk = pk.slice(2);
  }
  if( sk.startsWith("0x") )
  {
    sk = sk.slice(2);
  }
  const rk = PRE.generateReEncrytionKey(sk, pk);
  const rkHash = web3.utils.soliditySha3(rk);
  const responseData = {
    rk: rk,
    rkHash: rkHash
  };
  res.json(responseData);
});

app.post('/verify_vialID', (req, res) => {
  const { MRRoot, vialID, MRProof } = req.body

  // Validate the required fields
  if (!MRRoot || !vialID || !MRProof) {
    return res.status(400).json({ error: 'MRRoot, vialID, and MRProof are required fields.' });
  }

  try 
  {
    // Initialize an empty Merkle tree with the provided root hash
    const merkleTree = new MerkleTree([], keccak256, { sortPairs: true });
    // Get the root hash, data value, and Merkle proof from the request body
    const rootHash = MRRoot.trim();
    const merkleProof = MRProof;

    // Verify the data value and its Merkle proof
    const verificationResult = merkleTree.verify(merkleProof, keccak256(vialID), rootHash, keccak256);

    // Prepare the response data
    const responseData = {
      rootHash: rootHash,
      vialID: vialID,
      merkleProof: merkleProof,
      verificationResult: verificationResult
    };

    // Send the response
    res.json(responseData);
  } 
  catch (error) 
  {
    // Handle any errors that occur during tree construction or verification
    console.error('Error during verification:', error);
    res.status(500).json({ error: 'An error occurred during verification.', MRProof: MRProof, vialID: vialID, MRRoot: MRRoot });
  }
});


app.post('/compute_MR', (req, res) => {
    let vaccineData = req.body.dataInput.split(',').map(x => x.trim());
    //if vaccineData.length is not exact power of 2, reapet last element.
    let i = 0;
    while (vaccineData.length > Math.pow(2, i)) {
      i++;
    }
    const lastData = vaccineData[vaccineData.length - 1];
    let diff = Math.pow(2, i) - vaccineData.length;
    while (diff !== 0) {
      vaccineData.push(lastData);
      diff--;
    }
  
    const leafNodes = vaccineData.map(x => keccak256(x));
    const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
  
    const rootHash = merkleTree.getRoot().toString('hex');
  
    const proofs = vaccineData.map((item) => {
      const proof = merkleTree.getHexProof(keccak256(item));
      return { item, proof };
    }); 
  
    const responseData = { 
        vaccineData: vaccineData,
        length: vaccineData.length,
        leafCount: merkleTree.getLeafCount(),
        rootHash: rootHash,
        proofs: proofs,
    };

    res.json(responseData);
});

app.post('/compute_MR_Proof', (req, res) => {
  let vaccineData = req.body.vialsID;
  let element = req.body.element;
  //if vaccineData.length is not exact power of 2, reapet last element.
  let i = 0;
  while (vaccineData.length > Math.pow(2, i)) {
    i++;
  }
  const lastData = vaccineData[vaccineData.length - 1];
  let diff = Math.pow(2, i) - vaccineData.length;
  while (diff !== 0) {
    vaccineData.push(lastData);
    diff--;
  }

  const leafNodes = vaccineData.map(x => keccak256(x));
  const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
  const rootHash = merkleTree.getRoot().toString('hex');
  const proof = merkleTree.getHexProof(keccak256(element));
  const vialCommitment = web3.utils.soliditySha3(element);
  const mrProofCommitment = web3.utils.soliditySha3(...proof);

  const responseData = { 
      vaccineData: vaccineData,
      rootHash: rootHash,
      proof: proof,
      vialCommitment: vialCommitment,
      mrProofCommitment: mrProofCommitment
  };

  res.json(responseData);
});

app.post('/compute_crypto', async(req, res) => {
  let VP = req.body.Vaccine_Passport;
  let privateKey_Govt = req.body.Private_Key_Govt;
  let publicKey_C = req.body.Public_Key_C;
  //console.log(VP);
  //console.log(`privateKey_Govt: ${privateKey_Govt}`);
  //console.log(`publicKey_C: ${publicKey_C}`);
  if(privateKey_Govt.startsWith("0x") || privateKey_Govt.startsWith("0X"))
  {
    privateKey_Govt = privateKey_Govt.slice(2);
  }
  let address_Govt = derivePublicKeyAndAddress(privateKey_Govt).address;
  let govtAddr = "0x4d77E8A6D235d540Eb5cE251f5455F2e6A100287";
  let address_C;
  if(publicKey_C.startsWith("0x04") || publicKey_C.startsWith("0X04"))
  {
    address_C = ethUtil.publicToAddress(Buffer.from(publicKey_C.slice(4), 'hex')).toString('hex');
  }
  else
  if(publicKey_C.startsWith("04"))
  {
    address_C = ethUtil.publicToAddress(Buffer.from(publicKey_C.slice(2), 'hex')).toString('hex');
  }
  else
  {
    address_C = ethUtil.publicToAddress(Buffer.from(publicKey_C, 'hex')).toString('hex');
  }
  //console.log(`Eth_Addr_VC: ${address_Govt}`);
  //console.log(`Eth_Addr_C : ${address_C}`);
  let info_ok = true;
  let errorMessage_Govt = "";
  let errorMessage_C = "";
  let hash_of_VP = "";
  let signedMessageObject;
  let sign_of_VC_on_hash_VP = "";
  let encrypted_VP = {};
  let encrypted_VP_JSON = {};
  let cid ;

  if(govtAddr.toLowerCase() != '0x'+address_Govt.toLowerCase())
  {
    errorMessage_Govt = "Invalid Private Key!! Private Key does not match with the Govt's Ethereum Address.";
    info_ok = false;
  }
  if(VP['Citizen Ethereum Address'].toLowerCase() != '0x'+address_C.toLowerCase())
  {
    errorMessage_C = "Invalid Public Key!! Public Key does not match with citizen's Ethereum Address in VP.";
    info_ok = false;
  }
  if(!info_ok)
  {
    const responseData = { 
      errorMessage_Govt: errorMessage_Govt,
      errorMessage_C: errorMessage_C,
      hash_of_VP: hash_of_VP,
      sign_of_VC_on_hash_VP: sign_of_VC_on_hash_VP,
      cid: cid,
      encrypted_VP: encrypted_VP
    };
    res.json(responseData);
  }
  else
  {
    //1. Computing Hash of Vaccine Passport (VP)..
    const jsonString_VP = JSON.stringify(VP);
    //console.log("Json String of VP: " + jsonString_VP);
    hash_of_VP =  web3.utils.soliditySha3(jsonString_VP);
    //console.log("Hash of VP: " + hash_of_VP);

    //2. Create a Sign of Vaccination Center on the hash of VP..Require privateKey prefixd with '0x'
    if( privateKey_Govt.startsWith('0x') || privateKey_Govt.startsWith('0X') )
    {
      signedMessageObject = web3.eth.accounts.sign(hash_of_VP, privateKey_Govt);
    }
    else
    {
      signedMessageObject = web3.eth.accounts.sign(hash_of_VP, "0x"+privateKey_Govt);
    }
    sign_of_VC_on_hash_VP = signedMessageObject.signature;
    //console.log(signedMessageObject);
    //console.log("Signer's Ethereum Address: "+ web3.eth.accounts.recover(hash_of_VP,signedMessageObject.signature)); //returns signer ethereum address, if signature is valid..
    
    //3. Encrypt VP using Citizen's Public Key..Require compressed PublicKey(i.e. starting with 04) without '0x' as prefixed..
    if(publicKey_C.startsWith("0x"))
    {
      publicKey_C = publicKey_C.slice(2);
    }
    if(!publicKey_C.startsWith("04"))
    {
      publicKey_C = "04"+publicKey_C;
    }
    encrypted_VP = PRE.encryptData(publicKey_C, jsonString_VP);
    console.log('encrypted VP:');
    console.log(encrypted_VP);

    executeCommand('pgrep ipfs')
    .then((stdout) => {
      console.log('IPFS daemon is already running');
      return Promise.resolve();
    })
    .catch(() => {
      console.log('Please start IPFS daemon first and then run this code');
      return Promise.reject();
    })
    .then(() => {
      encrypted_VP_JSON = JSON.stringify(encrypted_VP);
      return executeCommand(`echo '${encrypted_VP_JSON}' | ipfs add -q`);
    })
    .then((CID) => {
        cid = CID.trim();
        console.log('File uploaded successfully. CID:', cid);

        const responseData = { 
          errorMessage_Govt: errorMessage_Govt,
          errorMessage_C: errorMessage_C,
          hash_of_VP: hash_of_VP,
          sign_of_VC_on_hash_VP: sign_of_VC_on_hash_VP,
          cid: cid,
          encrypted_VP: encrypted_VP
        };
        //console.log(responseData);
      
        res.json(responseData);
    })
    .catch((error) => {
      if (error) {
        console.error('Error occurred:', error);
      }
    });
  }
  
});

function derivePublicKeyAndAddress(privateKey) {
  const bufferPrivateKey = Buffer.from(privateKey, 'hex');
  const publicKey = ethUtil.privateToPublic(bufferPrivateKey);
  const address = ethUtil.publicToAddress(publicKey).toString('hex');
  //console.log("Public Key: "+ '0x'+publicKey.toString('hex'));
  //console.log("Address: "+ '0x'+address);
  return {
    publicKey: "04"+publicKey.toString('hex'), //'04' is appended to indicate uncompressed format of ethereum pubkey.
    address: address
  };

}


// Function to execute a command using the `exec` method
function executeCommand(command) {
  return new Promise((resolve, reject) => {
    exec(command, (error, stdout, stderr) => {
      if (error) {
        reject(`Command execution error: ${error}`);
        return;
      }

      if (stderr) {
        reject(`Command execution stderr: ${stderr}`);
        return;
      }

      resolve(stdout);
    });
  });
}


 app.listen(port, ipAddr, () => {
    console.log(`Server is running at http://${ipAddr}:${port}`);
 }); 
