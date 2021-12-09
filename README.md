# **Safle Token Contracts**

This repo contains the solidity contracts for Safle Token and Vesting.

#### **Token Contract**
Safle token is an ERC20 + Governance token for the Polygon chain. It contains all the standard ERC20 functionalities along with the methods to delegate votes and calculate votes.

#### **Vesting Contract**
The **vesting contract** has functionalities to initialize the vesting for an address and to withdraw the tokens after the cliff and slice period as per the allocation.

Methods to get the vesting schedule by index/beneficiary or by vesting schedule Id and to release the unlocked tokens have been implemented.

### **Deployments**

##### **From Remix**

1. The **token contract** is to be deployed first.
2. Once the **token contract** is deployed, the **vesting contract** should be deployed by passing the token contract address as the constructor parameter

##### **From Truffle**

1. Clone this repo using the command `git clone https://github.com/getsafle/token-contracts.git` and `cd token contracts`.
2. Install the dependencies using `npm ci`.
3. Install truffle using `npm install -g truffle`.
4. Run `truffle compile` to compile the contracts.
5. Deploy the contract to mainnet by running `truffle migrate --network mainnet` or to deploy to testnet, run `truffle migrate --network testnet`.

#### **Contract Addresses**

| Contract Name         | Network       | Contract Address                           |
|:---------------------:|:-------------:|:------------------------------------------:|
| Token Contract        | Testnet       | [0x1400cafa9c961e124265fac06e4a009fc7d93a3d](https://mumbai.polygonscan.com/tx/0x63699109406a619255cff029758db510f20a9fa9b9a190acc5546d75596998d0) |
| Vesting Contract      | Testnet       | [0x9a8cb9d7fb371ed4845a863979ec3f0578deb726](https://mumbai.polygonscan.com/tx/0xac22d4e9fdb0d8fc5b451356fc7c582cfb97a7f9aa0f1d33c7d0b3ddbf0e4c83) |