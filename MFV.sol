// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";



contract MFVRegistry is Pausable {


    uint256 public constant REQUIRED_APPROVALS = 2;
    uint256 public constant MAX_ADMINS = 4;
    uint256 public constant MIN_ADMINS = 2;


    constructor(address[] memory admins, address dataReaderAddress, bytes4[] memory initialActionCodes) {
        require( admins.length >= MIN_ADMINS && admins.length <= MAX_ADMINS,"MFV: Invalid admin count");

        require(dataReaderAddress != address(0), "Invalid dataReader address");
        require(initialActionCodes.length > 0, "MFV: no action codes");
        dataReader = dataReaderAddress;

        for (uint256 i = 0; i < admins.length; i++) {
            address admin = admins[i];

            require(admin != address(0), "Invalid admin address");
            require(!isAdmin[admin], "Duplicate admin");

            isAdmin[admin] = true;
            adminList.push(admin);

        }

        for (uint256 i = 0; i < initialActionCodes.length; i++) {
            bytes4 code = initialActionCodes[i];

            require(code != bytes4(0), "MFV: invalid action code");
            require(!actionCodeAllowed[code], "MFV: duplicate action code");

            actionCodeAllowed[code] = true;
            allowedActionCodes.push(code);
        }

    }



    event RoleCreated(bytes4 indexed roleId);
    event RoleAssignedToUser(bytes4 indexed userId, bytes4 indexed roleId);
    event RoleLinkedToActionCode(bytes4 indexed actionCode, bytes4 indexed roleId);
    event RoleUnLinkedToActionCode(bytes4 indexed actionCode, bytes4 indexed roleId);


    event ActionCodeAddRequested(bytes32 indexed requestId,bytes4 actionCode,address indexed requester,uint256 timestamp );
    event ActionCodeAddApproved(bytes32 indexed requestId,address indexed approver,uint256 approvalCount );
    event ActionCodeAdded(bytes4 actionCode,uint256 timestamp );

    event CrimeActionRecorded(bytes32 indexed crimeSceneId,bytes4 indexed actionCode,uint256 version,bytes4 userId, bytes32 merkleRoot,uint256 timestamp );
    event CrimeHistoryRead(bytes32 indexed crimeSceneId, bytes4 readerUserId, uint256 timestamp);

    event ExhibitActionRecorded(bytes32 indexed crimeSceneId,bytes32 indexed exhibitId,bytes4 indexed actionCode,uint256 version,bytes4 userId,bytes32 merkleRoot,uint256 timestamp);
    event ExhibitHistoryRead(bytes32 indexed crimeSceneId, bytes4 readerUserId,uint256 timestamp);

    event CrimeMediaRecorded(bytes32 indexed crimeSceneId,bytes32 indexed mediaId,bytes4 indexed actionCode,uint256 version,bytes4 userId,bytes32 mediaHash, uint256 timestamp);
    event CrimeMediaHistoryRead(bytes32 indexed crimeSceneId,bytes4 readerUserId,uint256 timestamp);
   
    event ExhibitMediaRecorded(bytes32 indexed crimeSceneId, bytes32 indexed exhibitId, bytes32 indexed mediaId,bytes4 actionCode, uint256 version, bytes4 userId, bytes32 mediaHash, uint256 timestamp );
    event ExhibitMediaHistoryRead(bytes32 indexed crimeSceneId, bytes4 readerUserId, uint256 timestamp );

    event PauseRequested(bytes32 indexed requestId, address indexed requester, uint256 timestamp );
    event UnpauseRequested(bytes32 indexed requestId, address indexed requester, uint256 timestamp );
    event PauseUnpauseApproved(bytes32 indexed requestId,address indexed approver,uint256 approvalCount );
    event ContractPaused(address indexed executor, uint256 timestamp );
    event ContractUnpaused(address indexed executor, uint256 timestamp );

    event SuspiciousTransactionsRead(bytes32 indexed crimeSceneId, bytes4 readerUserId, uint256 timestamp);
    event ExhibitCustodyHistoryAccessed( bytes32 indexed crimeSceneId, bytes4 indexed readerUserId, uint256 timestamp );



    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event AdminChangeRequested(bytes32 indexed requestId, address indexed target,bool makeAdmin,address indexed requester);
    event AdminChangeApproved( bytes32 indexed requestId, address indexed approver);

    event TransactionMarkedSuspicious( address indexed admin, bytes32 indexed crimeSceneId, uint256 timestamp, address markedBy, bytes4 actionCode );

    event ExhibitCustodyTransferred( bytes32 indexed crimeSceneId, bytes32 indexed exhibitId, bytes4 indexed fromUser, bytes4 toUser, bytes4 actionCode, bytes32 merkleRoot, uint256 timestamp);


    event RoleActionRemovalRequested( bytes32 indexed requestId, bytes4 indexed roleId, bytes4 indexed actionCode, address requester, uint256 timestamp);

    event RoleActionRemovalApproved( bytes32 indexed requestId, address indexed approver, uint256 approvalCount );

    event RoleRemovedFromActionCode( bytes4 indexed actionCode, bytes4 indexed roleId, uint256 timestamp);
    event CrimeCreated(bytes32 indexed crimeSceneId, bytes4 indexed createdBy, bytes4 indexed actionCode, uint256 timestamp);
    event CrimeClosed( bytes32 indexed crimeSceneId, bytes4 indexed closedBy, bytes4 indexed actionCode, uint256 timestamp );
    event UserCreated(bytes4 indexed userId, address indexed createdBy, uint256 timestamp);
    event RoleUpdatedForUser(bytes4 indexed userId, bytes4 indexed oldRoleId, bytes4 indexed newRoleId, uint256 timestamp);






    struct CrimeRevisions {
        bytes4 actionCode;         
        bytes32 merkleRoot;
        bytes32 ipfsCidHash;
        bytes4 userId;
        uint256 timestamp;
        uint256 version;
    }

    struct ExhibitRevision {
        bytes32 exhibitId;
        bytes4 actionCode;
        bytes32 merkleRoot;
        bytes32 ipfsCidHash;
        bytes4 userId;
        uint256 timestamp;
        uint256 version;
    }

    struct CrimeMediaRevision {
        bytes32 mediaId;
        bytes4 actionCode;
        bytes32 merkleRoot;
        bytes32 ipfsCidHash;
        bytes4 userId;
        uint256 timestamp;
        uint256 version;
    }

    struct ExhibitMediaRevision {
        bytes32 exhibitId;
        bytes32 mediaId;
        bytes4 actionCode;
        bytes32 merkleRoot;
        bytes32 ipfsCidHash;
        bytes4 userId;
        uint256 timestamp;
        uint256 version;
    }


    struct AdminChangeRequest {
        address target;
        bool makeAdmin;
        address[] approvers;
        bool executed;
    }

    struct PauseUnpauseRequest {
        bool pauseAction;
        address[] approvers;
        bool executed;
        uint256 timestamp;
    }

    struct ActionCodeRequest {
        bytes4 actionCode;
        address[] approvers;
        bool executed;
        uint256 timestamp;
    }

    struct RoleActionRemovalRequest {
        bytes4 roleId;
        bytes4 actionCode;
        address[] approvers;
        bool executed;
        uint256 timestamp;
    }


    struct SuspiciousTransaction {
        address admin;
        bytes32 crimeSceneId;
        uint256 timestamp;
        bytes4 actionCode;
    }

    struct ExhibitCustody {
        bytes32 exhibitId;
        bytes4 fromUser;
        bytes4 toUser;
        bytes4 actionCode;
        bytes32 merkleRoot;
        uint256 timestamp;
    }





    // ---------- ACTION CODE REGISTRY ----------
    bytes4[] public allowedActionCodes;
    address[] public adminList;
    address public immutable dataReader;

    mapping(bytes4 => bool) public actionCodeAllowed;
    mapping(address => bool) public isAdmin;

    mapping(bytes32 => AdminChangeRequest) public adminChangeRequests;
    mapping(bytes32 => PauseUnpauseRequest) public pauseUnpauseRequests;
    mapping(bytes32 => ActionCodeRequest) public actionCodeRequests;


    mapping(bytes32 => CrimeRevisions[]) private crimeHistory;
    mapping(bytes32 => ExhibitRevision[]) private exhibitHistory;

    mapping(bytes32 => CrimeMediaRevision[]) private crimeMediaHistory;
    mapping(bytes32 => ExhibitMediaRevision[]) private exhibitMediaHistory;

    mapping(bytes32 => SuspiciousTransaction[]) public suspiciousTransactionsByCrimeScene;

    mapping(bytes4 => bool) public roleExists;

    mapping(bytes4 => mapping(bytes4 => bool)) public userRoles;
    mapping(bytes4 => bytes4[]) private userAssignedRoles;

    mapping(bytes4 => mapping(bytes4 => bool)) public roleAllowedForAction;

    mapping(bytes32 => ExhibitCustody[]) private exhibitCustodyHistory;
    mapping(bytes32 => bytes4) public currentExhibitCustodian;

    mapping(bytes32 => RoleActionRemovalRequest) public roleActionRemovalRequests;
    mapping(bytes32 => bool) public crimeExists;
    mapping(bytes32 => bool) public crimeClosed;
    mapping(bytes4 => bool) public userExists;





    // ---------- MODIFIER ----------

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "MFV: not admin");
        _;
    }

    modifier onlyDataReader() {
        require(msg.sender == dataReader, "MFV: not authorized data reader");
        _;
    }

    modifier onlyAuthorized(bytes4 userId, bytes4 actionCode) {
      
        require(userExists[userId], "MFV: userId does not exist");


        bytes4[] memory roles = userAssignedRoles[userId];
        bool authorized = false;

        for (uint256 i = 0; i < roles.length; i++) {
            if (roleAllowedForAction[actionCode][roles[i]]) {
                authorized = true;
                break;
            }
        }

        require(authorized, "MFV: user not authorized for this action");
        _;
    }

    function createUser(bytes4 userId) external onlyAdmin whenNotPaused {
        require(userId != bytes4(0), "MFV: invalid userId");
        require(!userExists[userId], "MFV: userId already exists");

        userExists[userId] = true;

        emit UserCreated(userId, msg.sender, block.timestamp);
    }



    function createRole(bytes4 roleId) external onlyAdmin {
        require(roleId != bytes4(0), "MFV: invalid roleId");
        require(!roleExists[roleId], "MFV: role already exists");

        roleExists[roleId] = true;

        emit RoleCreated(roleId);
    }


    function allowRoleForActionCode(bytes4 roleId, bytes4 actionCode ) external onlyAdmin {
        
        require(roleId != bytes4(0), "MFV: invalid roleId");
        require(actionCode != bytes4(0), "MFV: invalid action code");
        require(roleExists[roleId], "MFV: role does not exist");
        require(actionCodeAllowed[actionCode], "MFV: action code not registered");

        roleAllowedForAction[actionCode][roleId] = true;

        emit RoleLinkedToActionCode(actionCode, roleId);
    }

    function requestRemoveRoleFromActionCode( bytes4 roleId, bytes4 actionCode ) external onlyAdmin whenNotPaused returns (bytes32) {

        require(roleId != bytes4(0), "MFV: invalid roleId");
        require(actionCode != bytes4(0), "MFV: invalid action code");
        require(roleExists[roleId], "MFV: role does not exist");
        require(actionCodeAllowed[actionCode], "MFV: action code not registered");
        require(roleAllowedForAction[actionCode][roleId], "MFV: role not linked");

        bytes32 requestId = keccak256(abi.encodePacked("REMOVE_ROLE_ACTION", roleId, actionCode, block.timestamp));

        require(roleActionRemovalRequests[requestId].timestamp == 0, "Request exists");

        RoleActionRemovalRequest storage req = roleActionRemovalRequests[requestId];
        req.roleId = roleId;
        req.actionCode = actionCode;
        req.approvers.push(msg.sender);
        req.executed = false;
        req.timestamp = block.timestamp;

        emit RoleActionRemovalRequested( requestId, roleId, actionCode, msg.sender, block.timestamp );

        return requestId;
    }

    function approveRemoveRoleFromActionCode(bytes32 requestId) external onlyAdmin whenNotPaused {
       
        RoleActionRemovalRequest storage req = roleActionRemovalRequests[requestId];

        require(req.timestamp != 0, "Request not found");
        require(!req.executed, "Already executed");

        // Prevent duplicate approvals
        for (uint256 i = 0; i < req.approvers.length; i++) {
            if (req.approvers[i] == msg.sender) {
                revert("Already approved");
            }
        }

        req.approvers.push(msg.sender);

        emit RoleActionRemovalApproved( requestId, msg.sender, req.approvers.length );

        if (req.approvers.length >= REQUIRED_APPROVALS) {
            _executeRemoveRoleFromActionCode(req);
        }
    }

    function _executeRemoveRoleFromActionCode( RoleActionRemovalRequest storage req) internal {
      
        require(!req.executed, "Already executed");
        require(roleAllowedForAction[req.actionCode][req.roleId], "Already removed");

        roleAllowedForAction[req.actionCode][req.roleId] = false;
        req.executed = true;

        emit RoleRemovedFromActionCode( req.actionCode, req.roleId, block.timestamp);
    }


    function removeRoleFromActionCode( bytes4 roleId, bytes4 actionCode) external onlyAdmin {

        require(roleId != bytes4(0), "MFV: invalid roleId");
        require(actionCode != bytes4(0), "MFV: invalid action code");
        require(roleExists[roleId], "MFV: role does not exist");
        require(actionCodeAllowed[actionCode], "MFV: action code not registered");
        require(roleAllowedForAction[actionCode][roleId],"MFV: role not linked to action");

        roleAllowedForAction[actionCode][roleId] = false;

        emit RoleUnLinkedToActionCode(actionCode, roleId);
    }

    function assignRoleToUser( bytes4 userId, bytes4 roleId ) external onlyAdmin {
        
        require(userExists[userId], "MFV: userId does not exist");
        require(roleId != bytes4(0), "MFV: invalid roleId");
        require(roleExists[roleId], "MFV: role does not exist");
        require(!userRoles[userId][roleId], "MFV: role already assigned");

        userRoles[userId][roleId] = true;
        userAssignedRoles[userId].push(roleId);

        emit RoleAssignedToUser(userId, roleId);
    }

    function updateRoleToUser( bytes4 userId, bytes4 oldRoleId, bytes4 newRoleId) external onlyAdmin {

        require(userExists[userId], "MFV: userId does not exist");
        require(roleExists[oldRoleId], "MFV: old role does not exist");
        require(roleExists[newRoleId], "MFV: new role does not exist");
        require(userRoles[userId][oldRoleId], "MFV: old role not assigned");
        require(!userRoles[userId][newRoleId], "MFV: new role already active");

        userRoles[userId][oldRoleId] = false;

        userRoles[userId][newRoleId] = true;
        userAssignedRoles[userId].push(newRoleId);

        emit RoleUpdatedForUser(userId, oldRoleId, newRoleId,block.timestamp);
    }

    function requestAddActionCode(bytes4 actionCode) external onlyAdmin whenNotPaused returns (bytes32) {
        require(actionCode != bytes4(0), "MFV: invalid action code");
        require(!actionCodeAllowed[actionCode], "MFV: already exists");

        bytes32 requestId = keccak256(
            abi.encodePacked("ADD_ACTION_CODE", actionCode, block.timestamp)
        );

        require(actionCodeRequests[requestId].timestamp == 0, "Request exists");

        ActionCodeRequest storage req = actionCodeRequests[requestId];
        req.actionCode = actionCode;
        req.approvers.push(msg.sender);
        req.executed = false;
        req.timestamp = block.timestamp;

        emit ActionCodeAddRequested(requestId, actionCode, msg.sender, block.timestamp);

        return requestId;
    }

    function approveAddActionCode(bytes32 requestId) external onlyAdmin whenNotPaused {
        ActionCodeRequest storage req = actionCodeRequests[requestId];

        require(req.timestamp != 0, "Request not found");
        require(!req.executed, "Already executed");

        // duplicate approval check
        for (uint i = 0; i < req.approvers.length; i++) {
            if (req.approvers[i] == msg.sender) {
                revert("Already approved");
            }
        }

        req.approvers.push(msg.sender);
        emit ActionCodeAddApproved(requestId, msg.sender, req.approvers.length);

        if (req.approvers.length >= REQUIRED_APPROVALS) {
            _executeAddActionCode(req);
        }

    }

    function _executeAddActionCode(ActionCodeRequest storage req) internal {
        require(!req.executed, "Already executed");
        require(!actionCodeAllowed[req.actionCode], "Already exists");

        actionCodeAllowed[req.actionCode] = true;
        allowedActionCodes.push(req.actionCode);

        req.executed = true;
        emit ActionCodeAdded(req.actionCode, block.timestamp);

    }   

    function _basicCheck( bytes4 userId, bytes32 crimeSceneId,bytes4 actionCode, bytes32 merkleRoot, bytes32 ipfsCidHash) internal pure {

        require(userId != bytes4(0), "MFV: empty userId");
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(actionCode != bytes4(0), "MFV: invalid action code");
        require(merkleRoot != bytes32(0), "MFV: invalid merkleRoot");
        require(ipfsCidHash != bytes32(0), "MFV: invalid ipfsCidHash");

    }

    function createCrime( bytes32 crimeSceneId, bytes4 userId, bytes4 actionCode ) external onlyAdmin onlyAuthorized(userId, actionCode) whenNotPaused {

        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(userId != bytes4(0), "MFV: invalid userId");

        require(!crimeExists[crimeSceneId], "MFV: crime already exists");

        crimeExists[crimeSceneId] = true;

        emit CrimeCreated(crimeSceneId, userId, actionCode, block.timestamp);
    }

    function recordCrimeAction( bytes4 userId, bytes32 crimeSceneId, bytes32 merkleRoot, bytes32 ipfsCidHash, bytes4 actionCode, uint256 currentVersion ) external onlyAdmin onlyAuthorized(userId, actionCode) whenNotPaused {
     
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        _basicCheck(userId, crimeSceneId, actionCode, merkleRoot, ipfsCidHash);
        

        
        require(actionCodeAllowed[actionCode], "MFV: invalid action code");


        uint256 version = crimeHistory[crimeSceneId].length + 1;

        require(currentVersion == version,"MFV: version Mismatch");

        crimeHistory[crimeSceneId].push(
            CrimeRevisions({
                actionCode: actionCode,
                merkleRoot: merkleRoot,
                ipfsCidHash: ipfsCidHash,
                userId: userId,
                timestamp: block.timestamp,
                version: version
            })
        );


        emit CrimeActionRecorded(crimeSceneId,actionCode, version, userId, merkleRoot, block.timestamp );

    }

    function getCrimeHistory( bytes32 crimeSceneId) external view onlyDataReader returns (CrimeRevisions[] memory) {
      
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        return crimeHistory[crimeSceneId];
    }

    function logCrimeHistoryRead(bytes32 crimeSceneId, bytes4 readerUserId) external onlyDataReader {
        require(readerUserId != bytes4(0), "MFV: empty reader userId");
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        emit CrimeHistoryRead(crimeSceneId, readerUserId, block.timestamp);
    }

    function _basicExhibitCheck( bytes4  userId, bytes32 crimeSceneId, bytes32 exhibitId, bytes4 actionCode, bytes32 merkleRoot) internal pure {
        require(userId != bytes4(0), "MFV: empty userId");
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(exhibitId != bytes32(0), "MFV: invalid exhibitId");
        require(actionCode != bytes4(0), "MFV: invalid action code");
        require(merkleRoot != bytes32(0), "MFV: invalid merkleRoot");

    }

    function recordExhibitAction(bytes4 userId,  bytes32 crimeSceneId, bytes32 exhibitId, bytes32 merkleRoot,bytes32 ipfsCidHash, bytes4 actionCode, uint256 currentVersion) external onlyAdmin onlyAuthorized(userId, actionCode) whenNotPaused {

        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        _basicExhibitCheck(userId, crimeSceneId, exhibitId, actionCode, merkleRoot);
        require(ipfsCidHash != bytes32(0), "MFV: invalid ipfsCidHash");
        require(actionCodeAllowed[actionCode], "MFV: invalid action code");

        uint256 version = exhibitHistory[crimeSceneId].length + 1;
        require(currentVersion == version, "MFV: version mismatch");

        exhibitHistory[crimeSceneId].push(
            ExhibitRevision({
                exhibitId: exhibitId,
                actionCode: actionCode,
                merkleRoot: merkleRoot,
                ipfsCidHash: ipfsCidHash,
                userId: userId,
                timestamp: block.timestamp,
                version: version
            })
        );

        emit ExhibitActionRecorded( crimeSceneId, exhibitId, actionCode, version, userId, merkleRoot, block.timestamp);

    }

    function getExhibitHistory( bytes32 crimeSceneId) external view onlyDataReader returns (ExhibitRevision[] memory) {
      
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        return exhibitHistory[crimeSceneId];
    }

    function logExhibitHistoryRead(bytes32 crimeSceneId, bytes4 readerUserId) external onlyDataReader {
        
        require(readerUserId != bytes4(0), "MFV: empty reader userId");
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");

        emit ExhibitHistoryRead(crimeSceneId, readerUserId, block.timestamp);

    }

    function _basicMediaCheck( bytes4 userId, bytes32 crimeSceneId, bytes32 mediaId, bytes4 actionCode, bytes32 merkleRoot ,bytes32 ipfsCidHash) internal pure {
        require(userId != bytes4(0), "MFV: empty userId");
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(mediaId != bytes32(0), "MFV: invalid mediaId");
        require(actionCode != bytes4(0), "MFV: invalid action code");
        require(merkleRoot != bytes32(0), "MFV: invalid merkleRoot Hash");
        require(ipfsCidHash != bytes32(0), "MFV: invalid ipfsCidHash");

    }

    function recordCrimeMedia(bytes4 userId, bytes32 crimeSceneId, bytes32 mediaId, bytes32 merkleRoot, bytes32 ipfsCidHash, bytes4 actionCode) external onlyAdmin onlyAuthorized(userId, actionCode) whenNotPaused {

        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        require(!crimeClosed[crimeSceneId], "MFV: crime is closed");
        _basicMediaCheck(userId, crimeSceneId, mediaId, actionCode, merkleRoot, ipfsCidHash);
        require(actionCodeAllowed[actionCode], "MFV: invalid action code");

        uint256 version = crimeMediaHistory[crimeSceneId].length + 1;

        crimeMediaHistory[crimeSceneId].push(
            CrimeMediaRevision({
                mediaId: mediaId,
                actionCode: actionCode,
                merkleRoot: merkleRoot,
                ipfsCidHash: ipfsCidHash,
                userId: userId,
                timestamp: block.timestamp,
                version: version
            })
        );

        emit CrimeMediaRecorded(crimeSceneId, mediaId, actionCode, version, userId, merkleRoot, block.timestamp);

    }

    function getCrimeMediaHistory( bytes32 crimeSceneId) external view onlyDataReader returns (CrimeMediaRevision[] memory) {
      
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        return crimeMediaHistory[crimeSceneId];
    }

    function logCrimeMedisHistoryRead(bytes32 crimeSceneId, bytes4 readerUserId) external onlyDataReader {
        require(readerUserId != bytes4(0), "MFV: empty reader userId");
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        emit CrimeMediaHistoryRead(crimeSceneId, readerUserId, block.timestamp);
    }

    function recordExhibitMedia( bytes4 userId,bytes32 crimeSceneId, bytes32 exhibitId, bytes32 mediaId, bytes32 merkleRoot, bytes32 ipfsCidHash, bytes4 actionCode) external onlyAdmin onlyAuthorized(userId, actionCode) whenNotPaused {

        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        _basicMediaCheck(userId, crimeSceneId, mediaId, actionCode, merkleRoot, ipfsCidHash);
        require(exhibitId != bytes32(0), "MFV: invalid exhibitId");
        require(actionCodeAllowed[actionCode], "MFV: invalid action code");

        uint256 version = exhibitMediaHistory[crimeSceneId].length + 1;

        exhibitMediaHistory[crimeSceneId].push(
            ExhibitMediaRevision({
                exhibitId: exhibitId,
                mediaId: mediaId,
                actionCode: actionCode,
                merkleRoot: merkleRoot,
                ipfsCidHash: ipfsCidHash,
                userId: userId,
                timestamp: block.timestamp,
                version: version
            })
        );

        emit ExhibitMediaRecorded(crimeSceneId, exhibitId, mediaId, actionCode, version, userId, merkleRoot, block.timestamp);

    }

    function getExhibitMediaHistory( bytes32 crimeSceneId) external view onlyDataReader returns (ExhibitMediaRevision[] memory) {
      
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        return exhibitMediaHistory[crimeSceneId];
    }

    function logCrimeExhibitMedisHistoryRead(bytes32 crimeSceneId, bytes4 readerUserId) external onlyDataReader {
        require(readerUserId != bytes4(0), "MFV: empty reader userId");
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        emit ExhibitMediaHistoryRead(crimeSceneId, readerUserId, block.timestamp);
    }

    function closeCrime( bytes32 crimeSceneId, bytes4 userId, bytes4 actionCode) external onlyAdmin onlyAuthorized(userId, actionCode) whenNotPaused {
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(userId != bytes4(0), "MFV: invalid userId");
        require(actionCode != bytes4(0), "MFV: invalid actionCode");

        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        require(!crimeClosed[crimeSceneId], "MFV: crime already closed");
        require(actionCodeAllowed[actionCode], "MFV: invalid action code");

        crimeClosed[crimeSceneId] = true;

        emit CrimeClosed(crimeSceneId, userId, actionCode, block.timestamp);
    }


    function requestAdminChange(address target, bool makeAdmin) external onlyAdmin returns(bytes32) {
        require(target != address(0), "Invalid address");
        
        if(makeAdmin) {
            require(!isAdmin[target], "Already admin");
            require(adminList.length < MAX_ADMINS, "MFV: Max admins limit reached");
        } else {
            require(isAdmin[target], "Not an admin");
            require(adminList.length > MIN_ADMINS, "MFV: Cannot reduce below minimum admins");
        }
        
        bytes32 requestId = keccak256(abi.encodePacked(target, makeAdmin, block.timestamp));
        
        require(adminChangeRequests[requestId].target == address(0), "Request already exists");
        
        AdminChangeRequest storage request = adminChangeRequests[requestId];
        request.target = target;
        request.makeAdmin = makeAdmin;
        request.approvers.push(msg.sender);
        request.executed = false;
        
        emit AdminChangeRequested(requestId, target, makeAdmin, msg.sender);
        emit AdminChangeApproved(requestId, msg.sender);
        
        return requestId;
    }

    function approveAdminChange(bytes32 requestId) external onlyAdmin {
        AdminChangeRequest storage request = adminChangeRequests[requestId];
        require(request.target != address(0), "Request does not exist");
        require(!request.executed, "Already executed");
        
        // Check if already approved
        for(uint i = 0; i < request.approvers.length; i++) {
            if(request.approvers[i] == msg.sender) {
                revert("Already approved");
            }
        }
        
        request.approvers.push(msg.sender);
        emit AdminChangeApproved(requestId, msg.sender);
        
        // Execute if enough approvals
        if(request.approvers.length >= REQUIRED_APPROVALS) {
            _executeAdminChange(request);
        }
    }
      
    function _executeAdminChange(AdminChangeRequest storage _request) internal {
        require(!_request.executed, "Already executed");
        
        if(_request.makeAdmin) {
            // Add admin
            require(!isAdmin[_request.target], "Already admin");
            require(adminList.length < MAX_ADMINS, "MFV: Max admins limit reached");
            
            isAdmin[_request.target] = true;
            adminList.push(_request.target);
            emit AdminAdded(_request.target);
        } else {
            // Remove admin
            require(isAdmin[_request.target], "Not an admin");
            require(adminList.length > MIN_ADMINS, "MFV: Cannot reduce below minimum admins");
            
            isAdmin[_request.target] = false;
            
            // Remove from adminList array
            for(uint i = 0; i < adminList.length; i++) {
                if(adminList[i] == _request.target) {
                    // Swap with last element and pop
                    adminList[i] = adminList[adminList.length - 1];
                    adminList.pop();
                    break;
                }
            }
            emit AdminRemoved(_request.target);
        }
        
        _request.executed = true;
    }
    
    function getAdminRequestInfo(bytes32 requestId) public view onlyDataReader returns ( address target, bool makeAdmin, address[] memory approvers, bool executed, uint256 approvalCount)  {
        AdminChangeRequest storage request = adminChangeRequests[requestId];

        return (request.target, request.makeAdmin,request.approvers, request.executed,request.approvers.length);
    }

    function getAllAdmins() public view onlyDataReader returns (address[] memory) {
        return adminList;
    }  

    function requestPause() external onlyAdmin returns(bytes32) {
        require(!paused(), "Already paused");
        
        bytes32 requestId = keccak256(abi.encodePacked("PAUSE", block.timestamp, msg.sender));
        require(pauseUnpauseRequests[requestId].timestamp == 0, "Request already exists");
        
        PauseUnpauseRequest storage request = pauseUnpauseRequests[requestId];
        request.pauseAction = true;
        request.approvers.push(msg.sender);
        request.executed = false;
        request.timestamp = block.timestamp;

        emit PauseRequested(requestId, msg.sender, block.timestamp);

        
        return requestId;
    }
    
    function requestUnpause() external onlyAdmin returns(bytes32) {
        require(paused(), "Not paused");
        
        bytes32 requestId = keccak256(abi.encodePacked("UNPAUSE", block.timestamp, msg.sender));
        require(pauseUnpauseRequests[requestId].timestamp == 0, "Request already exists");
        
        PauseUnpauseRequest storage request = pauseUnpauseRequests[requestId];
        request.pauseAction = false;
        request.approvers.push(msg.sender);
        request.executed = false;
        request.timestamp = block.timestamp;

        emit UnpauseRequested(requestId, msg.sender, block.timestamp);
        
        return requestId;
    }
    
    function approvePauseUnpause(bytes32 requestId) external onlyAdmin {
        PauseUnpauseRequest storage request = pauseUnpauseRequests[requestId];
        require(request.timestamp != 0, "Request does not exist");
        require(!request.executed, "Already executed");
        
        // Check if already approved
        for(uint i = 0; i < request.approvers.length; i++) {
            if(request.approvers[i] == msg.sender) {
                revert("Already approved");
            }
        }
        
        request.approvers.push(msg.sender);
        emit PauseUnpauseApproved(requestId, msg.sender, request.approvers.length);

        
        // Execute if enough approvals
        if(request.approvers.length >= REQUIRED_APPROVALS) {
            _executePauseUnpause(request);
        }
    }

    function _executePauseUnpause(PauseUnpauseRequest storage _request) internal {
        require(!_request.executed, "Already executed");
        
        if(_request.pauseAction) {
            _pause();
            emit ContractPaused(msg.sender, block.timestamp);
        } else {
            _unpause();
            emit ContractUnpaused(msg.sender, block.timestamp);

        }
        
        _request.executed = true;
    }
    
    function getPauseUnpauseRequest(bytes32 requestId) public view returns (
        bool pauseAction,
        address[] memory approvers,
        bool executed,
        uint256 timestamp,
        uint256 approvalCount
    ) {
        PauseUnpauseRequest storage request = pauseUnpauseRequests[requestId];
        require(request.timestamp != 0, "Request does not exist");
        
        return (
            request.pauseAction,
            request.approvers,
            request.executed,
            request.timestamp,
            request.approvers.length
        );
    }

    function markTransactionAsSuspicious( address admin, bytes32 crimeSceneId, bytes4 actionCode) external onlyAdmin whenNotPaused {
        require(crimeSceneId != bytes32(0), "MFV: Invalid crime scene ID");
        require(actionCode != bytes4(0), "MFV: Invalid action Code");
        require(isAdmin[admin], "MFV: Address is not an admin");
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        
        // Create new suspicious transaction record
        SuspiciousTransaction memory newSuspiciousTx = SuspiciousTransaction({
            admin: admin,
            crimeSceneId: crimeSceneId,
            timestamp: block.timestamp,
            actionCode: actionCode
        });
        
        // Store ONLY in crime scene mapping
        suspiciousTransactionsByCrimeScene[crimeSceneId].push(newSuspiciousTx);
        
        // Emit event with all required information
        emit TransactionMarkedSuspicious( admin, crimeSceneId, block.timestamp,msg.sender, actionCode);
    }

    function getSuspiciousTransactionsByCrimeScene(bytes32 crimeSceneId, bytes4 readerUserId) external view onlyDataReader  returns (SuspiciousTransaction[] memory) {
            
        require(readerUserId != bytes4(0), "MFV: empty reader userId");
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");

        return suspiciousTransactionsByCrimeScene[crimeSceneId];
    }

    function logGetSuspiciousTransactionsByCrimeScene(bytes32 crimeSceneId,bytes4 readerUserId) external onlyDataReader {
            
        require(readerUserId != bytes4(0), "MFV: empty reader userId");
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");

        emit SuspiciousTransactionsRead( crimeSceneId, readerUserId, block.timestamp);
    }


    function verifyCrimeData( bytes32 leafHash, bytes32[] calldata proof, bytes32 merkleRoot ) external view onlyDataReader returns (bool) {

        require(leafHash != bytes32(0), "MFV: invalid leafHash");
        require(merkleRoot != bytes32(0), "MFV: invalid leafHash");

        return MerkleProof.verify(proof, merkleRoot, leafHash);
    }

    function transferExhibitCustody(bytes4 fromUser, bytes4 toUser, bytes32 crimeSceneId, bytes32 exhibitId, bytes32 merkleRoot, bytes4 actionCode) external onlyAdmin onlyAuthorized(fromUser, actionCode) whenNotPaused {
        
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");
        _basicExhibitCheck(fromUser, crimeSceneId, exhibitId, actionCode, merkleRoot);

        require(toUser != bytes4(0), "MFV: invalid toUser");
        require(fromUser != toUser, "MFV: self transfer not allowed");

        if (currentExhibitCustodian[crimeSceneId] != bytes4(0)) {
            require(currentExhibitCustodian[crimeSceneId] == fromUser,"MFV: fromUser is not current custodian");
        }

        exhibitCustodyHistory[crimeSceneId].push(
            ExhibitCustody({
                exhibitId: exhibitId,
                fromUser: fromUser,
                toUser: toUser,
                actionCode: actionCode,
                merkleRoot: merkleRoot,
                timestamp: block.timestamp
            })
        );

        currentExhibitCustodian[crimeSceneId] = toUser;

        emit ExhibitCustodyTransferred(crimeSceneId, exhibitId, fromUser, toUser, actionCode, merkleRoot, block.timestamp);
    }

    function getExhibitCustodyHistory( bytes32 crimeSceneId, bytes4 readerUserId) external view onlyDataReader returns (ExhibitCustody[] memory){
        require(readerUserId != bytes4(0), "MFV: empty readerUserId");
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");

        return exhibitCustodyHistory[crimeSceneId];
    }


    function logGetExhibitCustodyHistory( bytes32 crimeSceneId, bytes4 readerUserId) external onlyDataReader{
        require(readerUserId != bytes4(0), "MFV: empty readerUserId");
        require(crimeSceneId != bytes32(0), "MFV: invalid crimeSceneId");
        require(crimeExists[crimeSceneId], "MFV: crime does not exist");

        emit ExhibitCustodyHistoryAccessed( crimeSceneId, readerUserId, block.timestamp);

    }







}