// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SafleToken is ERC20, Ownable {

    uint256 constant _totalSupply = 1000000000 * 10 ** 18;
    string constant _name = "Safle";
    string constant _symbol = "SAFLE";

    // mappings to keep track of delegations and change in the user balance for voting rights
    mapping (address => address) public delegates;
    mapping (address => uint256) public numCheckpoints;
    mapping (address => mapping (uint256 => Checkpoint)) public checkpoints;
    mapping (address => uint256) public nonces;

    // Allowance amounts on behalf of others
    mapping (address => mapping (address => uint96)) private allowances;
    
    // The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    // The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    struct Checkpoint {
        uint256 fromBlock;
        uint256 votes;
    }

    using SafeMath for uint256;

    address public governance;

    // whitelist and set the timelock address and distribute intial allocations
    constructor() ERC20(_name, _symbol) {
        _mint(msg.sender, _totalSupply);
    }
    
    /// @notice This function is used to revoke the admin access. The owner address with be set to 0x00..
    function revokeAdminAccess() public onlyOwner {
        return renounceOwnership();
    }

    // set the governance contract
    function setGovernance(address _governance) public onlyOwner {
        require(msg.sender == governance, "not governance contract");
        governance = _governance;
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `recepient`
     * @param recepient The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address recepient, uint256 amount) override public returns (bool) {
        _transfer(msg.sender, recepient, amount);
        _moveDelegates(delegates[msg.sender], delegates[recepient], amount);
        return true;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(address src, address dst, uint amount) override public returns (bool) {
        uint256 currentAllowance = allowances[src][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(src, _msgSender(), currentAllowance - amount);
        }

        _transfer(src, dst, amount);

        return true;
    }

    /**
    * @notice Delegate votes from `msg.sender` to `delegatee`
    * @param delegatee The address to delegate votes to
    */
    function delegate(address delegatee) public {
        return _delegate(msg.sender, delegatee);
    }

    /**
    * @notice Delegates votes from signatory to `delegatee`
    * @param delegatee The address to delegate votes to
    * @param nonce The contract state required to match the signature
    * @param expiry The time at which to expire the signature
    * @param v The recovery byte of the signature
    * @param r Half of the ECDSA signature pair
    * @param s Half of the ECDSA signature pair
    */
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), getChainId(), address(this)));
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "Safle::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "Safle::delegateBySig: invalid nonce");
        require(block.timestamp <= expiry, "Safle::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
    * @notice Gets the current votes balance for `account`
    * @param account The address to get votes balance
    * @return The number of current votes for `account`
    */
    function getCurrentVotes(address account) external view returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
    * @notice Determine the prior number of votes for an account as of a block number
    * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
    * @param account The address of the account to check
    * @param blockNumber The block number to get the vote balance at
    * @return The number of votes the account had as of the given block
    */
    function getPriorVotes(address account, uint256 blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "Safle::getPriorVotes: not yet determined");

        uint256 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    /// @notice Internal function to delegate the votes to another address
    /// @param delegator Address of the delegator
    /// @param delegatee Address of the delegatee

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator);
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    /// @notice Internal function to keep track of vote checkpoints
    /// @param source Source address of the token transfer
    /// @param destination Destination address of the token transfer
    /// @param amount Amount of token transferred
    function _moveDelegates(address source, address destination, uint256 amount) internal {
        if (source != destination && amount > 0) {
            if (source != address(0)) {
                uint256 srcRepNum = numCheckpoints[source];
                uint256 srcOldVotesCount = srcRepNum > 0 ? checkpoints[source][srcRepNum - 1].votes : 0;
                uint256 srcNewVotesCount = srcOldVotesCount.sub(amount);
                _writeCheckpoint(source, srcRepNum, srcOldVotesCount, srcNewVotesCount);
            }

            if (destination != address(0)) {
                uint256 dstRepNum = numCheckpoints[destination];
                uint256 dstOldVotesCount = dstRepNum > 0 ? checkpoints[destination][dstRepNum - 1].votes : 0;
                uint256 dstNewVotesCount = dstOldVotesCount.add(amount);
                _writeCheckpoint(destination, dstRepNum, dstOldVotesCount, dstNewVotesCount);
            }
        }
    }

    /// @notice Internal function to keep track of votes after token transfer
    /// @param delegatee Address of the vote delegatee
    /// @param nCheckpoints Number of checkpoints
    /// @param oldVotes votes prior to token transfer
    /// @param newVotes votes post token transfer
    function _writeCheckpoint(address delegatee, uint256 nCheckpoints, uint256 oldVotes, uint256 newVotes) internal {
        uint256 blockNumber = safe32(block.number, "Safle::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }
    
    function getChainId() internal view returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

}
