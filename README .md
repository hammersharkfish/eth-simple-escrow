
# An Ethereum based escrow system

## Introduction

There are 4 parties involved in this escrow system - 
     
Buyer

`Buyer` of a good/service. `Buyer` is the one who initiates  making a deal on-chain. 

Seller 

`Seller` of a good/service. The contract also tracks all deals made by the seller seperately so his reputation can be tracked.

Arbitrator 

`Arbitrator` A 3rd party which resolves a dispute in exchange for a commision.

Protocol owner

`Protocol Owner` deploys the contract. He also hosts a domain for providing an easy interface for making and tracking deals. He collects `PROTOCOL_BASE_BEE` + `addedProtocolFee`

`addedProtocolFee` = 
(`PROTOCOL_COMMISION_BPS`*`dealAmount`/10000) 

`PROTOCOL_COMMISION_BPS` and `PROTOCOL_BASE_BEE` are pre-defined while deploying the contract. 


## Installation

 
```bash
git clone https://github.com/hammersharkfish/eth-simple-escrow
```
In project directory
```bash
curl -L https://foundry.paradigm.xyz | bash
```
Open a new `bash` terminal 

```
foundryup
```

`lib/forge-std` is provided as is, to avoid the hassle of initializing a git repo.  



    
## Testing

To test this project run

```bash
  forge test -vvvvv --via-ir
```

