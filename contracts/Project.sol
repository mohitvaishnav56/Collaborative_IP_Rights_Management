// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Collaborative IP Rights Management
 * @dev Smart contract for managing fractional intellectual property rights and royalty distribution
 */
contract Project {
    
    struct IPAsset {
        string assetName;
        string assetType; // patent, artwork, music, content, etc.
        uint256 totalShares;
        uint256 totalRoyaltiesCollected;
        bool isActive;
        address creator;
    }
    
    struct Contributor {
        uint256 shares;
        uint256 lastClaimedRoyalty;
    }
    
    // Mapping from asset ID to IPAsset
    mapping(uint256 => IPAsset) public ipAssets;
    
    // Mapping from asset ID to contributor address to their contribution details
    mapping(uint256 => mapping(address => Contributor)) public contributors;
    
    // Mapping from asset ID to array of contributor addresses
    mapping(uint256 => address[]) public contributorList;
    
    uint256 public assetCounter;
    
    event IPAssetRegistered(uint256 indexed assetId, string assetName, address indexed creator);
    event SharesAllocated(uint256 indexed assetId, address indexed contributor, uint256 shares);
    event RoyaltyDeposited(uint256 indexed assetId, uint256 amount);
    event RoyaltyClaimed(uint256 indexed assetId, address indexed contributor, uint256 amount);
    
    /**
     * @dev Register a new IP asset with initial ownership
     * @param _assetName Name of the IP asset
     * @param _assetType Type of IP (patent, artwork, music, etc.)
     * @param _contributorAddresses Array of contributor addresses
     * @param _contributorShares Array of shares for each contributor (must sum to 10000 for 100%)
     */
    function registerIPAsset(
        string memory _assetName,
        string memory _assetType,
        address[] memory _contributorAddresses,
        uint256[] memory _contributorShares
    ) public returns (uint256) {
        require(_contributorAddresses.length == _contributorShares.length, "Address and shares length mismatch");
        require(_contributorAddresses.length > 0, "At least one contributor required");
        
        uint256 totalShares = 0;
        for (uint256 i = 0; i < _contributorShares.length; i++) {
            totalShares += _contributorShares[i];
        }
        require(totalShares == 10000, "Total shares must equal 10000 (100%)");
        
        uint256 assetId = assetCounter++;
        
        ipAssets[assetId] = IPAsset({
            assetName: _assetName,
            assetType: _assetType,
            totalShares: 10000,
            totalRoyaltiesCollected: 0,
            isActive: true,
            creator: msg.sender
        });
        
        for (uint256 i = 0; i < _contributorAddresses.length; i++) {
            address contributorAddr = _contributorAddresses[i];
            uint256 shares = _contributorShares[i];
            
            contributors[assetId][contributorAddr] = Contributor({
                shares: shares,
                lastClaimedRoyalty: 0
            });
            
            contributorList[assetId].push(contributorAddr);
            
            emit SharesAllocated(assetId, contributorAddr, shares);
        }
        
        emit IPAssetRegistered(assetId, _assetName, msg.sender);
        
        return assetId;
    }
    
    /**
     * @dev Deposit royalties for an IP asset (payable function)
     * @param _assetId ID of the IP asset
     */
    function depositRoyalty(uint256 _assetId) public payable {
        require(ipAssets[_assetId].isActive, "IP asset does not exist or is inactive");
        require(msg.value > 0, "Royalty amount must be greater than 0");
        
        ipAssets[_assetId].totalRoyaltiesCollected += msg.value;
        
        emit RoyaltyDeposited(_assetId, msg.value);
    }
    
    /**
     * @dev Claim accumulated royalties based on ownership shares
     * @param _assetId ID of the IP asset
     */
    function claimRoyalty(uint256 _assetId) public {
        require(ipAssets[_assetId].isActive, "IP asset does not exist or is inactive");
        
        Contributor storage contributor = contributors[_assetId][msg.sender];
        require(contributor.shares > 0, "No shares owned for this asset");
        
        uint256 totalRoyalties = ipAssets[_assetId].totalRoyaltiesCollected;
        uint256 contributorShare = (totalRoyalties * contributor.shares) / ipAssets[_assetId].totalShares;
        uint256 claimableAmount = contributorShare - contributor.lastClaimedRoyalty;
        
        require(claimableAmount > 0, "No royalties to claim");
        require(address(this).balance >= claimableAmount, "Insufficient contract balance");
        
        contributor.lastClaimedRoyalty += claimableAmount;
        
        payable(msg.sender).transfer(claimableAmount);
        
        emit RoyaltyClaimed(_assetId, msg.sender, claimableAmount);
    }
    
    /**
     * @dev Get contributor information for a specific asset
     * @param _assetId ID of the IP asset
     * @param _contributor Address of the contributor
     */
    function getContributorInfo(uint256 _assetId, address _contributor) 
        public 
        view 
        returns (uint256 shares, uint256 claimableRoyalty) 
    {
        Contributor memory contributor = contributors[_assetId][_contributor];
        uint256 totalRoyalties = ipAssets[_assetId].totalRoyaltiesCollected;
        uint256 contributorShare = (totalRoyalties * contributor.shares) / ipAssets[_assetId].totalShares;
        uint256 claimable = contributorShare - contributor.lastClaimedRoyalty;
        
        return (contributor.shares, claimable);
    }
    
    /**
     * @dev Get all contributors for a specific asset
     * @param _assetId ID of the IP asset
     */
    function getContributors(uint256 _assetId) public view returns (address[] memory) {
        return contributorList[_assetId];
    }
    
    // Fallback function to receive ether
    receive() external payable {}
}