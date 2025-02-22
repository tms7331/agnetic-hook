# Agnetic Agent Hook

## Description
Agnetic Agent Hook is a **Uniswap v4 Hook** built for the **EthGlobal Agentic Ethereum Hackathon**.

See a full description of the hackathon project here:
- [https://github.com/tms7331/agnetic-agent](https://github.com/tms7331/agnetic-agent)

And see the front end code here:
- [https://github.com/itali43/agneticFrontend](https://github.com/itali43/agneticFrontend)


## Installation
To use the **Agnetic Agent Hook**, follow these steps:

```sh
# Clone the repository
git clone https://github.com/tms7331/agnetic-hook
cd agnetic-agent-hook

# Install dependencies
forge install

# Compile the contracts
forge build

# Deploy the contracts to Base Sepolia
forge script script/00_DeployAll.s.sol --broadcast --rpc-url https://sepolia.base.org --private-key <YOUR_PRIVATE_KEY>
forge script script/00_HookCalls.s.sol --broadcast --rpc-url https://sepolia.base.org --private-key <YOUR_PRIVATE_KEY>
```

## License
This project is licensed under the MIT License.