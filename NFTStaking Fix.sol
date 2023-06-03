// SPDX-License-Identifier: MIT LICENSE

pragma solidity 0.8.4;

import "./PepePolice.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTStaking is Ownable, IERC721Receiver {

  uint256 public totalStaked;
  mapping(address => uint256[]) private _stakedTokens;
  uint256 public tokenPrice;
  bool    public isStart; 
  // struct to store a stake's token, owner, and earning values
  struct Stake {
    uint24 tokenId;
    uint48 timestamp;
    address owner;
  }

  event NFTStaked(address owner, uint256 tokenId, uint256 value);
  event NFTUnstaked(address owner, uint256 tokenId, uint256 value);
  event Claimed(address owner, uint256 amount);

// reference to the Block NFT contract
  ERC721Enumerable nft;
  PepePolice token;

// maps tokenId to stake
  mapping(uint256 => Stake) public vault; 
 
  receive() external payable {}

   constructor(address _nft, address _token) { 
    nft = ERC721Enumerable(_nft);
    token = PepePolice(_token);
  }

  function stake(uint256[] calldata tokenIds) external {
    uint256 tokenId;
    totalStaked += tokenIds.length;
    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      require(nft.ownerOf(tokenId) == msg.sender, "not your token");
      require(vault[tokenId].tokenId == 0, 'already staked');

      nft.transferFrom(msg.sender, address(this), tokenId);
      emit NFTStaked(msg.sender, tokenId, block.timestamp);
      _stakedTokens[msg.sender].push(tokenId);

      vault[tokenId] = Stake({
        owner: msg.sender,
        tokenId: uint24(tokenId),
        timestamp: uint48(block.timestamp)
      });
    }
  }

  function _unstakeMany(address account, uint256[] calldata tokenIds) internal {
    uint256 tokenId;
    uint256 idx;
    uint256 lastIndex;
    totalStaked -= tokenIds.length;
    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      Stake memory staked = vault[tokenId];
      require(staked.owner == account, "not an owner");

      delete vault[tokenId];
      emit NFTUnstaked(account, tokenId, block.timestamp);
      nft.transferFrom(address(this), account, tokenId);
	    lastIndex = _stakedTokens[account].length;
      for( idx = 0; idx < lastIndex; idx++){
        if(_stakedTokens[account][idx] == tokenId)
          break;
      }
      if( idx < lastIndex - 1){
        _stakedTokens[account][idx] = _stakedTokens[account][lastIndex-1];
      }
      delete _stakedTokens[account][lastIndex-1];
      _stakedTokens[account].pop();
    }
  }

  function claim(uint256[] calldata tokenIds) external {
      _claim(msg.sender, tokenIds, false);
  }

  function claimForAddress(address account, uint256[] calldata tokenIds) external {
      _claim(account, tokenIds, false);
  }

  function unstake(uint256[] calldata tokenIds) external {
      _claim(msg.sender, tokenIds, true);
  }

  function _claim(address account, uint256[] calldata tokenIds, bool _unstake) internal {
    uint256 tokenId;
    uint256 earned = 0;
    uint256 rewardmath = 0;
    
    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      Stake memory staked = vault[tokenId];
      require(staked.owner == account, "not an owner");
      uint256 stakedAt = staked.timestamp;
      rewardmath = 100 ether * (block.timestamp - stakedAt) / 86400 ;
      earned += rewardmath / 100;
      vault[tokenId] = Stake({
        owner: account,
        tokenId: uint24(tokenId),
        timestamp: uint48(block.timestamp)
      });
    }
    if (earned > 0) {
      if(!isStart){
	      uint256 payamounts=earned * tokenPrice/ (10**18);
        require(payamounts>0);
	      payable(account).transfer(payamounts);
      }
      else{
        require(earned>0); 
	      token.transfer(account, earned);
      }
    }
    if (_unstake) {
      _unstakeMany(account, tokenIds);
    }
    emit Claimed(account, earned);
  }
  
  function setTokenPrice(uint256 _tokenPrice) external onlyOwner {
       tokenPrice = _tokenPrice;
  }

  function setStartStatus(bool _isStart) external onlyOwner {
       isStart = _isStart;
  }

  function earningInfo(address account, uint256[] calldata tokenIds) external view returns (uint256[1] memory info) {
     uint256 tokenId;
     uint256 earned = 0;
     uint256 rewardmath = 0;

    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      Stake memory staked = vault[tokenId];
      require(staked.owner == account, "not an owner");
      uint256 stakedAt = staked.timestamp;
      rewardmath = 100 ether * (block.timestamp - stakedAt) / 86400;
      earned += rewardmath / 100;

    }
    if (earned > 0) {
      return [earned];
    }
}

  function balanceOf(address account) public view returns (uint256) {
    uint256 balance = 0;
    uint256 supply = nft.totalSupply();
    for(uint i = 1; i <= supply; i++) {
      if (vault[i].owner == account) {
        balance += 1;
      }
    }
    return balance;
  }

  function tokensOfOwner(address account) public view returns (uint256[] memory ownerTokens) {

    return _stakedTokens[account];
  }

  function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
      require(from == address(0x0), "Cannot send nfts to Vault directly");
      return IERC721Receiver.onERC721Received.selector;
    }
  
}


