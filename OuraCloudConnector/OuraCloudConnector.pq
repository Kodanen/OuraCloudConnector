// This file contains your Data Connector logic
section OuraCloudConnector;

// OuraCloud OAuth2 values
client_id = Text.FromBinary(Extension.Contents("client_id.txt"));
client_secret = Text.FromBinary(Extension.Contents("client_secret.txt"));
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "https://api.ouraring.com/oauth/token";
authorize_uri = "https://cloud.ouraring.com/oauth/authorize";
logout_uri = "https://login.microsoftonline.com/logout.srf";

// Data uris
api_uri = "https://api.ouraring.com/v1/";
readiness_uri = "readiness";
sleep_uri = "sleep";
activity_uri = "activity";

// Login modal window dimensions
windowWidth = 720;
windowHeight = 1024;

// default page size, using the MAX page size to limit the amount of calls to the API
page_size = 200;

// OAuth2 scope
scope_prefix = "";
scopes = {
    "daily"
};

[DataSource.Kind="OuraCloudConnector", Publish="OuraCloudConnector.UI"]
shared OuraCloudConnector.Contents = OuraData.NavTable;

// Data Source Kind description
OuraCloudConnector= [
    TestConnection = (dataSourcePath) => { "OuraCloudConnector.Contents" }, // , dataSourcePath
    Authentication = [
        OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh,
            Logout=Logout,
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
OuraCloudConnector.UI = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = OuraCloudConnector.Icons,
    SourceTypeImage = OuraCloudConnector.Icons
];

OuraCloudConnector.Icons = [
    Icon16 = { Extension.Contents("OuraCloudConnector16.png"), Extension.Contents("OuraCloudConnector20.png"), Extension.Contents("OuraCloudConnector24.png"), Extension.Contents("OuraCloudConnector32.png") },
    Icon32 = { Extension.Contents("OuraCloudConnector32.png"), Extension.Contents("OuraCloudConnector40.png"), Extension.Contents("OuraCloudConnector48.png"), Extension.Contents("OuraCloudConnector64.png") }
];

// NavTable
OuraData.NavTable = () as table => 
    let 
        source = #table({"Name", "Data"}, {
            { "Readiness", OuraData.Readiness }, //GetObject(readiness_uri,"Readiness")
            { "Sleep", OuraData.Sleep }, // GetObject(sleep_uri,"Sleep")
            { "Activity", OuraData.Activity } // GetObject(activity_uri,"Activity")
        }),
        
        // add other columns
        withItemKind = Table.AddColumn(source, "ItemKind", each "Table"),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table"),
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true),

        functionTable = AddNavTableFunctions({[Name = "GetObjects", Data = OuraData.GetObject]}),

        withFunction = Table.InsertRows(withIsLeaf, Table.RowCount(withIsLeaf) - 1, {[ 
            Name = "Functions",
            Data = functionTable,
            ItemKind = "Folder",
            ItemName = "Folder",
            IsLeaf = false
        ]}),
        
        navTable = Table.ToNavigationTable(withFunction, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;

// Readiness
OuraData.Readiness = 
    let        
        source = OuraData.GetObject(readiness_uri & "?start=2019-01-01" ,"Readiness")
        //source = Json.Document(Web.Contents(api_uri & readiness_uri & "?start=2020-05-01")),
        
        //ConvertToTable = Table.FromList(source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        //tableresult = Record.ToTable(ConvertToTable),
        //result = Table.Pivot(tableresult, List.Distinct(tableresult[Name]), "Name", "Value"),
        //result2 = Table.ExpandListColumn(result, "readiness"),
        //result3 = Table.ExpandRecordColumn(result2, "readiness", {"period_id", "score", "score_activity_balance", "score_hrv_balance", "score_previous_day", "score_previous_night", "score_recovery_index", "score_resting_hr", "score_sleep_balance", "score_temperature", "summary_date"}, {"period_id", "score", "score_activity_balance", "score_hrv_balance", "score_previous_day", "score_previous_night", "score_recovery_index", "score_resting_hr", "score_sleep_balance", "score_temperature", "summary_date"}),
        //result4 = null
    in
        source;

// Sleep
OuraData.Sleep =
    let
        source = OuraData.GetObject(sleep_uri & "?start=2019-01-01" ,"Sleep")
    in 
        source;

// Activity
OuraData.Activity = //(json) =>
    let
        source = OuraData.GetObject(activity_uri & "?start=2019-01-01" ,"Activity")
    in 
        source;


//All of the paging is based off the Tripin Sample https://github.com/Microsoft/DataConnectors/tree/master/samples/TripPin/5-Paging 

// Note: Taking in a full path is a security issue, as it could potentially leak 
// the bearer token to the url specified in the function parameter. 
OuraData.GetObject = (relativeUrl as text, contentType as text) => OuraData.PagedReader(api_uri & relativeUrl, contentType);


// Read a single page of data.
// If we get back an empty list, it means we are out of pages and should return null.
// For Strava I added an additional parameter to determine the type of content so we can parse this differently later
OuraData.Page = (url as text, page as number, contentType as text) as nullable table =>
    let
        queryOptions = [
            page = Number.ToText(page),
            page_size = Text.From(page_size)
        ],
        content = Web.Contents(url, [ Query = queryOptions ]),
        json = Json.Document(content),

        // Responses from the API will either be a single record, or list of records.
        // When we have a single record, we want to format it as a table. Set NextPage to null.
        // When we have a list of records, we convert to a table. Set NextPage to page + 1.
        // When we have an empty list of records, we return null. 
        result =
            if (json is list) then
                if (List.IsEmpty(json)) then 
                    null
                else //Determine how to parse the JSON based on the type of content.
                    if(contentType = "Readiness") then
                        OuraData.Readiness(json) meta [NextPage = page + 1]                        
                    else if(contentType = "Sleep") then
                        OuraData.Sleep(json) meta [NextPage = page + 1]
                    else if(contentType = "Activity") then
                        OuraData.Activity(json) meta [NextPage = page + 1]
                    else 
                        // Why?
                        OuraData.Activity(json) meta [NextPage = page + 1]
            else
                Table.FromRecords({json}) meta [NextPage = null] // turn single record into one item list
    in
        result;

// Read all pages of data.
// After every page, we check the "NextPage" record on the metadata of the previous request.
// Table.GenerateByPage will keep asking for more pages until we return null.
OuraData.PagedReader = (url as text, contentType as text) =>
    Table.GenerateByPage((previous) => 
        let
            // if previous is null, then this is our first page of data
            nextPage = if (previous = null) then 1 else Value.Metadata(previous)[NextPage]?,
            // if NextPage was set to null by the previous call, we know we have no more data
            page = if (nextPage <> null) then OuraData.Page(url, nextPage, contentType) else null
        in
            page
    );

// This is a modified version of Table.ToNavigationTable to expose the function invocation dialog in the navigator.
// This works around the issue described here: https://github.com/Microsoft/DataConnectors/issues/30
// The functions argument is a list of records with Name and Data fields.
AddNavTableFunctions = (functions as list) as table =>
    let
        asTable = Table.FromRecords(functions),
        withItemKind = Table.AddColumn(asTable, "ItemKind", each "Function"),
        withIsLeaf = Table.AddColumn(withItemKind, "IsLeaf", each true),

        tableType = Value.Type(withIsLeaf),
        newTableType = Type.AddTableKey(tableType, {"Name"}, true) meta 
        [
            NavigationTable.NameColumn = "Name", 
            NavigationTable.DataColumn = "Data",
            NavigationTable.ItemKindColumn = "ItemKind", 
            NavigationTable.IsLeafColumn = "IsLeaf"
        ],
        navigationTable = Value.ReplaceType(withIsLeaf, newTableType)
    in
        navigationTable;

// 
// **** Authentication
//
//For authentication I used: https://github.com/Microsoft/DataConnectors/tree/master/samples/Github

//
// Authentication functions
//
StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            client_id = client_id,
            scope = GetScopeString(scopes, scope_prefix),
            response_type = "code",
            state = state,
            redirect_uri = redirect_uri])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        // parse the full callbackUri, and extract the Query string
        parts = Uri.Parts(callbackUri)[Query],
        // if the query string contains an "error" field, raise an error
        // otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", "code", parts[code])
    in
        result;


// Called when the access_token has expired, and a refresh_token is available.
Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);

// see "Exchange code for access token: POST /oauth/token" at https://cloud.ouraring.com/docs/authentication for details
TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            grant_type = "authorization_code",
            redirect_uri = redirect_uri,
            client_id = client_id,
            client_secret = client_secret
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        tokenResponse = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;

// Logout
Logout = (token) => logout_uri;

// Get scope string
GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        prefix = Value.IfNull(scopePrefix, ""),
        addPrefix = List.Transform(scopes, each prefix & _),
        asText = Text.Combine(addPrefix, " ")
    in
        asText;

//
// **** Helper functions
//

// Table to navigation
 Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

// Table generator
Table.GenerateByPage = (getNextPage as function) as table =>
    let
        listOfPages = List.Generate(
            () => getNextPage(null),
            (lastPage) => lastPage <> null,
            (lastPage) => getNextPage(lastPage)
        ),
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0}?
    in
        if (firstRow = null) then
            Table.FromRows({})
        else
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );

// Value Null
Value.IfNull = (a, b) => if a <> null then a else b;
        
