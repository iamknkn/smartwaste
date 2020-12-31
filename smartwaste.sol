// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;


contract SmartWaste{
    
    enum Role {Office, responsibleAuth, trashCollector, user}   // enum datatype to compare role of person in block chain
    uint peopleInvolved = 0;                                    // maintains a count of totalpeople added to block chain 

    /*stores all the information about a person*/
    struct Person {
        uint identifier;
        Role primaryrole;
        Role secondaryrole;
        string name;
        bool isActive;
        string location;
        string optional;
        uint areaCode;
        uint userRequestCount;
        uint binReqCount;
        bool activeReq;
        bool binAlloted;
        uint binNum;
        uint quantity;
    }
    
    /*holds the userRequests for particular area as a struct*/
    struct User {
        uint identifier;
        address add;
        string name;
        string location;
        bool isVerified;
        uint areaCode;
    }
    
    /*Stores data of  bin deployed in an area as a struct */
    struct Bin {
        uint id;
        string locality;
        uint binCapacity;
        uint binSpaceLeft;
        bool isWorking;
        uint pendingDump;
    }
    
    /*holds the dumpRequests for particular area as a struct*/
    struct dumpReqs {
        uint weight;
        address userAddress;
    }
    
    address private higherAuth;             // holds the address of the account that deployed the contract
        
    mapping(uint => User[]) private userRequests;       // trashAreaCode    =>      User[]
    mapping(address => Person) private people;          // address          =>      Person
    mapping(uint => address) private addresses;         // peopleInvolved   =>      address
    mapping(uint => Bin[]) private areaBins;            // trashAreaCode    =>      Bin[]
    mapping(uint => uint) private allBins;              // BinID            =>      trashAreaCode
    mapping(uint => address) private idToAddressMap;    // AadhaarID        =>      address
    mapping(uint => address) private authAppointed;     // trashAreaCode    =>      address
    mapping(uint => dumpReqs[]) private  trashReqs;     // trashAreaCode    =>      dumpReqs[]
    
    /*Access modifier for functions to check if sender is higherAuth or not*/
    modifier isHigherAuth() {
        if(higherAuth != msg.sender)
        {
            revert("Aceess Error : Higher Auth required");
        }
        else{
            _;
        }
    }
    
    /*Access modifier for functions to check if sender is LocalAuth or not*/
    modifier isLocalAuth() {
        if(people[msg.sender].primaryrole != Role.responsibleAuth)
        {
            revert("Aceess Error : Local Auth required");
        }
        else{
            _;
        }
    }
    
    /*Access modifier for functions to check if sender is an Authority(either higherAuth or LocalAuth) or not*/
    modifier isAuth() {
        if(msg.sender == higherAuth || people[msg.sender].primaryrole == Role.responsibleAuth)
        {
          _;
        }
        else
        {
            revert("Aceess Error : HIgher or Local Auth required");
        }
    }
    
    /* returns true if  person exists in blockchain (based on account address) */
    function personExists(address a) private view returns (bool) {
        for(uint i = 0; i < peopleInvolved;i++)
        {
            if(addresses[i] == a) return true;
        }
        return false;
    }
    
    /*returns false if  person exists in blockchain (based on account address) */
    function personNotExists(address a) private view returns (bool) {
        return !personExists(a);
    }
    
    /*returns index of bin in areaBins mapping for  particular areaCode*/
    function findBin(uint trashAreaCode, uint bid, uint len) private view returns (uint) {
        for (uint i = 0;  i < len; i++) {
            if(areaBins[trashAreaCode][i].id == bid) {
                return i;
            }
        }
        return len;
    }
    
    /*creates a Person struct and adds it to people mapping*/
    function addPerson(Person storage Comm, string memory name, uint id, Role r, string memory reg, uint trash) private {
        Comm.name = name;
        Comm.identifier = id;
        Comm.areaCode = trash;
        Comm.primaryrole = r;
        Comm.secondaryrole = Role.user;
        Comm.location = reg;
        Comm.isActive = true;
        Comm.userRequestCount = 0;
    }

    /*takes array of persons' details(if given) for different Local authorities and initialises*/
    constructor(address[] memory authority, string[] memory names, uint[] memory Aadhaar_IDs, string[] memory regions, uint[] memory trashAreaCodes) {
        higherAuth = msg.sender;
        for(uint i = 0; i < authority.length; i++)
        {
        require(authAppointed[trashAreaCodes[i]] == address(0), "Authority already present for an area");
        authAppointed[trashAreaCodes[i]] = authority[i];
        idToAddressMap[Aadhaar_IDs[i]] = authority[i];
        addresses[peopleInvolved] = authority[i];
        peopleInvolved  += 1;
        Person storage Com = people[authority[i]];
        addPerson(Com, names[i], Aadhaar_IDs[i], Role.responsibleAuth, regions[i], trashAreaCodes[i]);
        }
            
        
    }
    
    /*appooints an authority for a particular trashAreaCode*/
    function appointAuthority(address pers, string memory his_name, uint Aadhaar_ID, string memory locate, uint trashAreaCode) public isHigherAuth{
        require(personNotExists(pers) || people[pers].primaryrole != Role.responsibleAuth, "Person already exists in records as an authority");
        require(authAppointed[trashAreaCode] == address(0), "Authority already present for this area");
        authAppointed[trashAreaCode] = pers;
        if(personNotExists(pers))
        {
        addresses[peopleInvolved] = pers;
        peopleInvolved  += 1;
        }
        Person storage Com = people[pers];
        idToAddressMap[Aadhaar_ID] = pers;
        addPerson(Com, his_name, Aadhaar_ID, Role.responsibleAuth, locate, trashAreaCode);
    }
    
    /*appooints a trash Collector for a particular trashAreaCode*/
    function appointTrashCollector(address pers, string memory his_name, uint Aadhaar_ID, string memory locate, uint trashAreaCode) public isAuth{
        require(personNotExists(pers) || people[pers].primaryrole == Role.user, "Person already exists in records as a non-user");
        if (msg.sender != higherAuth)
        {
        require(people[msg.sender].areaCode == trashAreaCode, "Area does not come under your responsibility");
        }
        if(personNotExists(pers))
        {
        addresses[peopleInvolved] = pers;
        peopleInvolved  += 1;
        }
        Person storage Com = people[pers];
        idToAddressMap[Aadhaar_ID] = pers;
        addPerson(Com, his_name, Aadhaar_ID, Role.trashCollector, locate, trashAreaCode);

    }
    
    /*authority of a particular trashAreaCode is terminated */
    function terminateAuthority(address add, uint Aadhaar_ID, string memory reason_to_terminate, uint trashAreaCode) public isHigherAuth{
        require(people[add].identifier == Aadhaar_ID, "Credentials do not match. Please check again!!");
        require(people[add].primaryrole == Role.responsibleAuth, "Person is not a Local Authority");
        people[add].optional = reason_to_terminate;
        authAppointed[trashAreaCode] = address(0);
        activateAsUser(add);
    }
    
    /*specified trashCollector of a particular trashAreaCode is terminated */
    function terminateTrashCollector(address add, uint Aadhaar_ID, string memory reason_to_terminate) public isAuth{
        require(people[add].identifier == Aadhaar_ID, "Credentials do not match. Please check again!!");
        require(people[add].primaryrole == Role.trashCollector, "Person is not a trash collector");
        if(people[msg.sender].primaryrole == Role.responsibleAuth)
        {
            require(people[msg.sender].areaCode == people[add].areaCode, "Person doesn't come under area authorised for you");
        }
        people[add].optional = reason_to_terminate;
        activateAsUser(add);
    }
    
    /* terminated person (authority/trashCollector) is made as user in that Area*/
    function activateAsUser(address a) private {
        people[a].primaryrole = Role.user;
    }
    
    /* creates a user requests through which person can request to get authorised as user */
    function NewUser(string memory name, string memory locate, uint Aadhaar_ID, uint trashAreaCode) public {
        require(!people[msg.sender].isActive, "User already registered");
        require(personNotExists(msg.sender),"Account terminated...contact local authority for details");
        require(idToAddressMap[Aadhaar_ID] == address(0), "userRequest exists" );
        address auth = authAppointed[trashAreaCode];
        require(auth != address(0), "Local Authority is not active yet for this area");
        User memory u;
        u.identifier = Aadhaar_ID;
        u.add = msg.sender;
        u.name = name;
        u.location = locate;
        u.isVerified = false;
        u.areaCode = trashAreaCode;
        idToAddressMap[Aadhaar_ID] = msg.sender;
        userRequests[trashAreaCode].push(u);
        people[authAppointed[trashAreaCode]].userRequestCount += 1;
    }
    
    /*user request is approved and person is added as a user*/
    function authorizeUser(uint Aadhaar_ID) public isLocalAuth {
        address userAdd = idToAddressMap[Aadhaar_ID];
        uint trashAreaCode = people[msg.sender].areaCode;
        uint req = 0;
        for(uint i = 0; i < people[msg.sender].userRequestCount; i++)
        {
            if(userRequests[trashAreaCode][i].identifier == Aadhaar_ID)
            {
                req = i+1;
                break;
            }
        }
        require(req != 0, "Corresponding user request not found");
        req -= 1;
        require(userRequests[trashAreaCode][req].areaCode == people[msg.sender].areaCode, "Person doesn't come under area authorised for you");
        require(!userRequests[trashAreaCode][req].isVerified, "User is already Verified");
        addresses[peopleInvolved] = userAdd;
        peopleInvolved  += 1;
        Person storage Com = people[userAdd];
        addPerson(Com, userRequests[trashAreaCode][req].name, Aadhaar_ID, Role.user, userRequests[trashAreaCode][req].location, trashAreaCode);
        userRequests[trashAreaCode][req].isVerified = true;
        people[msg.sender].userRequestCount -= 1;
        uint newLen = people[msg.sender].userRequestCount;
        if (req != newLen) {
            for(uint i = req; i < newLen; i++) {
                userRequests[trashAreaCode][i] = userRequests[trashAreaCode][i+1];
            }
        }
        delete userRequests[trashAreaCode][newLen];
    }
    
    /* new bin is added to the area*/
    function deployBin(uint id, string memory street, uint trashAreaCode, uint capacity) public isLocalAuth {
        require(people[msg.sender].areaCode == trashAreaCode,"Area doesn't come under your responsibility");
        require(allBins[id] == 0, "Bin already present");
        Bin memory b;
        b.id = id;
        b.locality = street;
        b.binCapacity = capacity;
        b.binSpaceLeft = capacity;
        b.isWorking = true;
        areaBins[trashAreaCode].push(b);
        allBins[id] = trashAreaCode;
    }
    
    /*creates a dumpReqs struct for the user in an area */
    function reqToDumpTrash(uint trashQuantity) public {
        require(people[msg.sender].secondaryrole == Role.user, "User not found");
        require(!people[msg.sender].activeReq,"You already have an active request");
        uint trashAreaCode = people[msg.sender].areaCode;
        dumpReqs memory r;
        r.userAddress = msg.sender;
        r.weight = trashQuantity;
        trashReqs[trashAreaCode].push(r);
        people[authAppointed[trashAreaCode]].binReqCount += 1;
        people[msg.sender].quantity = trashQuantity;
        people[msg.sender].activeReq = true;
    }
    
    /*allots bin for user to dump the req amount of trash */
    function allotBin(uint AadhaarID, uint BinID) public isLocalAuth {
        uint dd = people[idToAddressMap[AadhaarID]].areaCode;
        require(people[msg.sender].areaCode == dd,"Area doesn't come under your responsibility");
        require(allBins[BinID] != 0, "Wrong Bin ID");
        address addr = idToAddressMap[AadhaarID];
        require(addr != address(0), "Invalid AadhaarID");
        uint l = areaBins[dd].length;
        uint bin_no = findBin(dd, BinID, l);
        require(bin_no != l, "Bin not found in this area");
        uint effSpace = areaBins[dd][bin_no].binSpaceLeft - areaBins[dd][bin_no].pendingDump;
        require(effSpace >= people[idToAddressMap[AadhaarID]].quantity, " insufficient space in bin specified");
        people[addr].binNum = BinID;
        people[idToAddressMap[AadhaarID]].binAlloted = true;
        people[authAppointed[dd]].binReqCount -= 1;
        areaBins[dd][bin_no].pendingDump += people[idToAddressMap[AadhaarID]].quantity;
        uint len = people[authAppointed[dd]].binReqCount;
        uint j = l;
        for (uint i = 0; i < l; i++) {
            if(trashReqs[dd][i].userAddress == addr)
            {
                j = i;
                break;
            }
        }
        if(j != len) {
            for(uint i = j; i < len; i++) {
                trashReqs[dd][i] = trashReqs[dd][i+1];
            }
        }
        delete trashReqs[dd][len];
    }
    
    /*returns binId of bin alloted to user by Local authority (0 if no bin is alloted)*/
    function checkIfBinAlloted() public view returns (uint binIDAlloted) {
        if(people[msg.sender].binAlloted) {
         return people[msg.sender].binNum;
        }
        return 0;
    }
    
    /*trash gets dumped into bin by user reducing bin space available*/
    function dumpTrash() public {
        require(checkIfBinAlloted() != 0, "You are not permitted to dump (no request found / no bin alloted");
        uint binId = people[msg.sender].binNum;
        uint trashAreaCode = people[msg.sender].areaCode;
        uint l = areaBins[trashAreaCode].length;
        uint bin_no = findBin(trashAreaCode, binId, l);
        areaBins[trashAreaCode][bin_no].binSpaceLeft -= people[msg.sender].quantity;
        areaBins[trashAreaCode][bin_no].pendingDump -= people[msg.sender].quantity;
        people[msg.sender].quantity = 0;
        people[msg.sender].activeReq = false;
        people[msg.sender].binAlloted = false;
        people[msg.sender].binNum = 0;
        
    }
    
    /*trashCollectors clean the Bin making bin capacity maximum again*/
    function cleanBin(uint BinID) public {
        uint trashAreaCode = allBins[BinID];
        require(trashAreaCode != 0, "Bin does not exist");
        require(people[msg.sender].primaryrole == Role.trashCollector, "Only trashCollector can empty the bin");
        require(people[msg.sender].areaCode == trashAreaCode, "Area does not come under your responsibility");
        uint l = areaBins[trashAreaCode].length;
        uint bin_no = findBin(trashAreaCode, BinID, l);
        areaBins[trashAreaCode][bin_no].binSpaceLeft = areaBins[trashAreaCode][bin_no].binCapacity;
    }
    
    /*lists requests made by people in an area to get registered*/
    function listUserRequests(uint trashAreaCode) public view isAuth returns (uint[] memory Aadhaar_IDs, string[] memory names, string[] memory locations) {
        if(msg.sender != higherAuth)
        {
        require(people[msg.sender].areaCode == trashAreaCode, "Operation Access Denied : You are not permitted to view this Area details");
        }
        uint len = people[authAppointed[trashAreaCode]].userRequestCount;
        require(len > 0, "no user requests");
        uint[] memory ids = new uint[](len);
        string[] memory namz = new string[](len);
        string[] memory locationz = new string[](len);
        for (uint i = 0; i < len; i++) {
          User memory u = userRequests[trashAreaCode][i];
          ids[i] = u.identifier;
          namz[i] = u.name;
          locationz[i] = u.location;
          
        }
        return (ids, namz, locationz);
    }
    
    /*lists requests made by users in an area for dumping trash*/
    function listDumpRequests(uint trashAreaCode) public view isAuth returns (uint[] memory Aadhaar_IDs, string[] memory names, string[] memory locations, uint[] memory quantInKgs){
        if(msg.sender != higherAuth) {
        require(people[msg.sender].areaCode == trashAreaCode, "Operation Access Denied : You are not permitted to view this Area details");
        }
        uint len = people[authAppointed[trashAreaCode]].binReqCount;
        require(len > 0, "no dump requests");
        uint[] memory ids = new uint[](len);
        uint[] memory quan = new uint[](len);
        string[] memory namz = new string[](len);
        string[] memory locationz = new string[](len);
        for (uint i = 0; i < len; i++) {
          dumpReqs memory r = trashReqs[trashAreaCode][i];
          address s = r.userAddress;
          ids[i] = people[s].identifier;
          namz[i] = people[s].name;
          locationz[i] = people[s].location;
          quan[i] = r.weight;
          
        }
        return (ids, namz, locationz, quan);
    }
    
    /*lists bins deployed in a trashAreaCode and their occupancy details*/
    function listBins(uint trashAreaCode) public view returns (uint[] memory ids, uint[] memory capacities, uint[] memory spaceLeft) {
        if(msg.sender != higherAuth)
        {
        require(people[msg.sender].areaCode == trashAreaCode, "Operation Access Denied : You are not permitted to view this Area details");
        }
        uint len = areaBins[trashAreaCode].length;
        require(len > 0, "no bins deployed");
        uint[] memory idz = new uint[](len);
        uint[] memory capLeft = new  uint[](len);
        uint[] memory eff = new  uint[](len);
        uint j = 0;
        for(uint i = 0; i < len; i++)
        {
            Bin memory b = areaBins[trashAreaCode][i];
            uint l = b.binSpaceLeft - b.pendingDump;
            if(l != 0)
            {
            idz[j] = b.id;
            capLeft[j] = b.binSpaceLeft;
            eff[j] = l;
            j += 1;
            }
        }
        
        return (idz, capLeft, eff);
         
    }

}


