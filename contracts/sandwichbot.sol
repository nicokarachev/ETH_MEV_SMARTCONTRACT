// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SandwichBot {

    address internal constant UNISWAPV2_TEST_ROUTER_ADDRESS = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;
    address internal constant UNISWAPV2_TEST_FACTORY_ADDRESS = 0xB7926C0430Afb07AA7DEfDE6DA862aE0Bde767bc;
    address internal constant UNISWAPV2_ROUTER_ADDRESS = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address internal constant UNISWAPV2_FACTORY_ADDRESS = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;

    IUniswapV2Router02 public pcsRouter;
    uint constant MAX_UINT = 2**256 - 1;
    mapping (address => uint[2]) resv;
    mapping (address => uint) pendingWithdrawals;
    address payable owner;

    event Received(address sender, uint amount);

    constructor(){
        pcsRouter = IUniswapV2Router02(UNISWAPV2_TEST_ROUTER_ADDRESS);
        owner = payable(msg.sender);
    }

    modifier onlyOwner { 
       require(
           msg.sender == owner, "Only owner can call this function."
       );
       _;
   }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function getReserves(address[] memory tokenAddress, address[] memory routerAddress) public view returns(uint[] memory resv0, uint[] memory resv1){
        uint[] memory resv0 = new uint[](tokenAddress.length);
        uint[] memory resv1 = new uint[](tokenAddress.length);
        uint resv_0;
        uint resv_1;
        for(uint i=0;i<tokenAddress.length;i++){
            (resv_0, resv_1) = getReserve(tokenAddress[i], routerAddress[i]);
            resv0[i] = resv_0;
            resv1[i] = resv_1;
        }
        return (resv0,resv1);
    }

    function getReserve(address tokenAddress, address routerAddress) public view returns(uint resv0, uint resv1){
        address factoryAddress = UNISWAPV2_FACTORY_ADDRESS;

        if( routerAddress == UNISWAPV2_TEST_ROUTER_ADDRESS ){
            factoryAddress = UNISWAPV2_TEST_FACTORY_ADDRESS;
        }
        IUniswapV2Factory factory = IUniswapV2Factory(factoryAddress);
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
        IUniswapV2Pair pair;
        address pairAddress = factory.getPair(router.WETH(), tokenAddress);
        pair = IUniswapV2Pair(pairAddress);
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        uint resv0;
        uint resv1;
        if(router.WETH() == pair.token0()){
            resv0 = reserve0;
            resv1 = reserve1;
        }
        else
        {
            resv0 = reserve1;
            resv1 = reserve0;
        }
        return (resv0, resv1);
    }

    function buyToken(uint ethAmount, address tokenAddress, address routerAddress) public payable onlyOwner {
        uint buyAmount;

        // if ethAmount > balance then change ethAmount to address balance
        if(ethAmount > address(this).balance){
            buyAmount = address(this).balance;
        }else{
            buyAmount = ethAmount;
        }
        require(buyAmount <= address(this).balance, "Not enough ETH");
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = tokenAddress;
        router.swapExactETHForTokens{value: buyAmount}(0, path, address(this), block.timestamp + 1);
    }

    function sellToken(address tokenAddress, address routerAddress) public onlyOwner payable {
        IERC20 token = IERC20(tokenAddress);
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = router.WETH();
        uint tokenBalance = token.balanceOf(address(this));
        if(token.allowance(address(this), routerAddress) < tokenBalance){
            require(token.approve(routerAddress, MAX_UINT),"FAIL TO APPROVE");
        }
        router.swapExactTokensForETH(tokenBalance,0,path,address(this),block.timestamp + 10);
    }

    function emergencySell(address tokenAddress, address routerAddress) public onlyOwner payable returns (bool status){
        IERC20 token = IERC20(tokenAddress);
        uint tokenBalance = token.balanceOf(address(this));
        if(token.allowance(address(this), routerAddress) < tokenBalance){
            require(token.approve(routerAddress, MAX_UINT),"FAIL TO APPROVE");
        }
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = router.WETH();
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenBalance, 0, path, address(this), block.timestamp + 10);
        return true;
    }

    function withdraw() public onlyOwner payable{
        owner.transfer(address(this).balance);
    }

    function withdrawToken(address tokenAddress, address to) public payable onlyOwner returns (bool res){
        IERC20 token = IERC20(tokenAddress);
        bool result = token.transfer(to, token.balanceOf(address(this)));
        return result;
    }
}
