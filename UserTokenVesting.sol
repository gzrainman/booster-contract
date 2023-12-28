// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function decimals() external view  returns (uint8);

    function burn(uint256 amount) external returns (bool);
}

/** 
 * @title UserTokenVesting
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the
 * owner.
 */
contract UserTokenVesting is Ownable {
    /**
    * TurboGlobal Address
    */
    IERC20 private immutable tgb_token;

    /**
    * Variable k supports 5 decimal places
    */
    uint8 private _kDecimals = 5;

    /**
    * @dev Variable price supports 18 decimal places
    * 0.01 = 10000000000000000
    */
    uint8 private _priceDecimals = 18;

    /**
    * @dev Calculate unlocking formula parameters 
    * 50000 = 0.5
    */
    uint private _k = 50000;

    uint32 private SECONDS_PER_DAY = 86400;

    /**
    * Maximum daily token release
    */
    uint256 private day_max_token = 50000;

    /**
    * @dev Record the unlocking date of the dau
    */
    uint32 private release_day = 0;

    /**
    * @dev Unlocked tokens to be allocated
    */
    uint256 public wait_allocation = 0;

    constructor(IERC20 _token) {
        tgb_token = _token;
    }

    /**
    * @dev Release collected tokens and destroy unclaimed tokens.
    * This function can only be executed by contract administrators in the background.
    */
    function release(address recipient,  uint256 total, uint256 received) public virtual onlyOwner  returns (bool){
        require(recipient != address(0), "release: recipient is the zero address");
        require(total > 0, "claimPointsDrop: total Cannot be empty");
        require(received > 0, "claimPointsDrop: received Cannot be empty");
        require(total >= received, "claimPointsDrop: The total allocation number must be greater than or equal to the received amount");

        uint32 d = uint32(block.timestamp % 2 ** 32)/SECONDS_PER_DAY;
        require(d != release_day, "claimPointsDrop: Today Dua has unlocked the token");

        release_day = d;

        uint dayMaxAmount = 10**tgb_token.decimals() * day_max_token;
        if(total > dayMaxAmount){
            total = dayMaxAmount;
        }
        if(received > dayMaxAmount){
            received = dayMaxAmount;
        }

        tgb_token.transfer(recipient, received);
        if(total > received){
            tgb_token.burn(total - received);
        }

        if(dayMaxAmount > total){
            wait_allocation = wait_allocation + (dayMaxAmount - total);
        }

        return true;
    }

    /**
    * @dev Destroy wait allocation TurboGlobal
    * This method can only be executed by administrators
    * amount: The amount of destroy
    */
    function unClaimBurn(uint256 amount) public virtual onlyOwner returns (bool){
        require(amount > 0, "burn: the amount must be greater than 0");
        require(amount <= wait_allocation, "burn: burn _amount greater than wait_allocation");
        wait_allocation = wait_allocation - amount;
        return tgb_token.burn(amount);
    }

    /**
     *@dev Transfer out tokens to be allocated.
      This method can only be executed by administrators
    */
    function transfer(address recipient, uint256 amount) public virtual returns (bool) {
        require(amount > 0, "burn: the amount must be greater than 0");
        require(amount <= wait_allocation, "burn: burn _amount greater than wait_allocation");
        wait_allocation = wait_allocation - amount;
        tgb_token.transfer(recipient,amount);
        return true;
    }

    function setUserFuncParaK(uint k) public virtual onlyOwner returns (bool){
        _k = k;
        return true;
    }

    function checkUserFuncParaK() public view returns (uint) {
        return _k;
    }

    /**
     * @dev Calculate the daily unlocked TurboGlobal based on DAU
     * dau: User points
     * price: Token price
     */
    function userTokenFunc(uint256 dau, uint256 price) public view returns (uint256) {
        if(dau <= 0 || price <=0){
            return 0;
        }
        uint256 p = 10**_priceDecimals;
        uint256 tok = (dau * _k * p) / price;
        uint8 decimals = tgb_token.decimals();
        tok = tok * (10**(decimals - kdecimals()));
        return tok;
    }

    function kdecimals() public view returns (uint8){
        return _kDecimals;
    }

    function priceDecimals() public view returns (uint8){
        return _priceDecimals;
    }

}
