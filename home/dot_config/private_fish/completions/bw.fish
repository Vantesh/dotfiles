function __fish_subcommand_satisfies
    set -l cmd (commandline -poc)
    set -e cmd[1]
    set -l len (count $argv)

    if test (count $cmd) -lt $len
        return 1
    end

    for i in (seq $len)
        if test $cmd[$i] != $argv[$i]
            return 1
        end
    end

    return 0
end

function __fish_subcommand_is
    set -l cmd (commandline -poc)
    set -e cmd[1]

    if test (count $cmd) -ne (count $argv)
        return 1
    end

    __fish_subcommand_satisfies $argv
end

function __fish_no_subcommand
    set -l cmd (commandline -poc)
    set -e cmd[1]
    test (count $cmd) -eq 0
end

complete -c bw -f

# Global Options ---------------------------------------------------------------
complete -c bw -l pretty -d 'Format output. JSON is tabbed with two spaces.'
complete -c bw -l raw -d 'Return raw output instead of a descriptive message.'
complete -c bw -l response -d 'Return a JSON formatted version of response output.'
complete -c bw -l cleanexit -d 'Exit with a success exit code (0) unless an error is thrown.'
complete -c bw -l quiet -d 'Don\'t return anything to stdout.'
complete -c bw -l nointeraction -d 'Do not prompt for interactive user input.'
complete -c bw -l session -d 'Pass session key instead of reading from env.'
complete -c bw -s v -l version -d 'output the version number'
complete -c bw -s h -l help -d 'display help for command'

# Main Subcommands -------------------------------------------------------------
# sdk-version
complete -c bw -n __fish_no_subcommand -a sdk-version -d 'Print the SDK version.'

# login
complete -c bw -n __fish_no_subcommand -a login -d 'Log into a user account.'
complete -c bw -n '__fish_subcommand_satisfies login' -l method -d 'Two-step login method.'
complete -c bw -n '__fish_subcommand_satisfies login' -l code -d 'Two-step login code.'
complete -c bw -n '__fish_subcommand_satisfies login' -l sso -d 'Log in with Single-Sign On with optional organization identifier.'
complete -c bw -n '__fish_subcommand_satisfies login' -l apikey -d 'Log in with an Api Key.'
complete -c bw -n '__fish_subcommand_satisfies login' -l passwordenv -a '(set -nx)' -d 'Environment variable storing your password'
complete -c bw -n '__fish_subcommand_satisfies login' -l passwordfile -a '(ls -A)' -d 'Path to a file containing your password as its first line'
complete -c bw -n '__fish_subcommand_satisfies login' -l check -d 'Check login status.'

# logout
complete -c bw -n __fish_no_subcommand -a logout -d 'Log out of the current user account.'

# lock
complete -c bw -n __fish_no_subcommand -a lock -d 'Lock the vault and destroy active session keys.'

# unlock
complete -c bw -n __fish_no_subcommand -a unlock -d 'Unlock the vault and return a new session key.'
complete -c bw -n '__fish_subcommand_satisfies unlock' -l check -d 'Check lock status.'
complete -c bw -n '__fish_subcommand_satisfies unlock' -l passwordenv -a '(set -nx)' -d 'Environment variable storing your password'
complete -c bw -n '__fish_subcommand_satisfies unlock' -l passwordfile -a '(ls -A)' -d 'Path to a file containing your password as its first line'

# sync
complete -c bw -n __fish_no_subcommand -a sync -d 'Pull the latest vault data from server.'
complete -c bw -n '__fish_subcommand_satisfies sync' -s f -l force -d 'Force a full sync.'
complete -c bw -n '__fish_subcommand_satisfies sync' -l last -d 'Get the last sync date.'

# generate
complete -c bw -n __fish_no_subcommand -a generate -d 'Generate a password/passphrase.'
complete -c bw -n '__fish_subcommand_satisfies generate' -s u -l uppercase -d 'Include uppercase characters.'
complete -c bw -n '__fish_subcommand_satisfies generate' -s l -l lowercase -d 'Include lowercase characters.'
complete -c bw -n '__fish_subcommand_satisfies generate' -s n -l number -d 'Include numeric characters.'
complete -c bw -n '__fish_subcommand_satisfies generate' -s s -l special -d 'Include special characters.'
complete -c bw -n '__fish_subcommand_satisfies generate' -s p -l passphrase -d 'Generate a passphrase.'
complete -c bw -n '__fish_subcommand_satisfies generate' -l length -d 'Length of the password.'
complete -c bw -n '__fish_subcommand_satisfies generate' -l words -d 'Number of words.'
complete -c bw -n '__fish_subcommand_satisfies generate' -l minNumber -d 'Minimum number of numeric characters.'
complete -c bw -n '__fish_subcommand_satisfies generate' -l minSpecial -d 'Minimum number of special characters.'
complete -c bw -n '__fish_subcommand_satisfies generate' -l separator -d 'Word separator.'
complete -c bw -n '__fish_subcommand_satisfies generate' -s c -l capitalize -d 'Title case passphrase.'
complete -c bw -n '__fish_subcommand_satisfies generate' -l includeNumber -d 'Passphrase includes number.'
complete -c bw -n '__fish_subcommand_satisfies generate' -l ambiguous -d 'Avoid ambiguous characters.'

# encode
complete -c bw -n __fish_no_subcommand -a encode -d 'Base 64 encode stdin.'

# config
complete -c bw -n __fish_no_subcommand -a config -d 'Configure CLI settings.'
complete -c bw -n '__fish_subcommand_is config' -a server -d 'On-premises hosted installation URL.'
complete -c bw -n '__fish_subcommand_satisfies config' -l web-vault -d 'Provides a custom web vault URL that differs from the base URL.'
complete -c bw -n '__fish_subcommand_satisfies config' -l api -d 'Provides a custom API URL that differs from the base URL.'
complete -c bw -n '__fish_subcommand_satisfies config' -l identity -d 'Provides a custom identity URL that differs from the base URL.'
complete -c bw -n '__fish_subcommand_satisfies config' -l icons -d 'Provides a custom icons service URL that differs from the base URL.'
complete -c bw -n '__fish_subcommand_satisfies config' -l notifications -d 'Provides a custom notifications URL that differs from the base URL.'
complete -c bw -n '__fish_subcommand_satisfies config' -l events -d 'Provides a custom events URL that differs from the base URL.'
complete -c bw -n '__fish_subcommand_satisfies config' -l key-connector -d 'Provides the URL for your Key Connector server.'

# update
complete -c bw -n __fish_no_subcommand -a update -d 'Check for updates.'

# completion
complete -c bw -n __fish_no_subcommand -a completion -d 'Generate shell completions.'
complete -c bw -n '__fish_subcommand_is completion' -l shell -a 'zsh bash fish powershell'

# status
complete -c bw -n __fish_no_subcommand -a status -d 'Show server, last sync, user information, and vault status.'

# list
complete -c bw -n __fish_no_subcommand -a list -d 'List an array of objects from the vault.'
complete -c bw -n '__fish_subcommand_is list' -a 'items folders collections org-collections org-members organizations'
complete -c bw -n '__fish_subcommand_satisfies list' -l search -d 'Perform a search on the listed objects.'
complete -c bw -n '__fish_subcommand_satisfies list' -l url -d 'Filter items of type login with a url-match search.'
complete -c bw -n '__fish_subcommand_satisfies list' -l folderid -d 'Filter items by folder id.'
complete -c bw -n '__fish_subcommand_satisfies list' -l collectionid -d 'Filter items by collection id.'
complete -c bw -n '__fish_subcommand_satisfies list' -l organizationid -d 'Filter items or collections by organization id.'
complete -c bw -n '__fish_subcommand_satisfies list' -l trash -d 'Filter items that are deleted and in the trash.'

# get
complete -c bw -n __fish_no_subcommand -a get -d 'Get an object from the vault.'
complete -c bw -n '__fish_subcommand_is get' -a 'item username password uri totp notes exposed attachment folder collection org-collection organization template fingerprint send'
complete -c bw -n '__fish_subcommand_satisfies get' -l itemid -d 'Attachment\'s item id.'
complete -c bw -n '__fish_subcommand_satisfies get' -l output -a '(ls -A)' -d 'Output directory or filename for attachment.'
complete -c bw -n '__fish_subcommand_satisfies get' -l organizationid -d 'Organization id for an organization object.'

# create
complete -c bw -n __fish_no_subcommand -a create -d 'Create an object in the vault.'
complete -c bw -n '__fish_subcommand_is create' -a 'item attachment folder org-collection'
complete -c bw -n '__fish_subcommand_satisfies create' -l file -a '(ls -A)' -d 'Path to file for attachment.'
complete -c bw -n '__fish_subcommand_satisfies create' -l itemid -d 'Attachment\'s item id.'
complete -c bw -n '__fish_subcommand_satisfies create' -l organizationid -d 'Organization id for an organization object.'

# edit
complete -c bw -n __fish_no_subcommand -a edit -d 'Edit an object from the vault.'
complete -c bw -n '__fish_subcommand_is edit' -a 'item item-collections folder org-collection'
complete -c bw -n '__fish_subcommand_satisfies edit' -l organizationid -d 'Organization id for an organization object.'

# delete
complete -c bw -n __fish_no_subcommand -a delete -d 'Delete an object from the vault.'
complete -c bw -n '__fish_subcommand_is delete' -a 'item attachment folder org-collection'
complete -c bw -n '__fish_subcommand_satisfies delete' -l itemid -d 'Attachment\'s item id.'
complete -c bw -n '__fish_subcommand_satisfies delete' -l organizationid -d 'Organization id for an organization object.'
complete -c bw -n '__fish_subcommand_satisfies delete' -s p -l permanent -d 'Permanently deletes the item instead of soft-deleting it (item only).'

# restore
complete -c bw -n __fish_no_subcommand -a restore -d 'Restores an object from the trash.'
complete -c bw -n '__fish_subcommand_is restore' -a item

# move
complete -c bw -n __fish_no_subcommand -a move -d 'Move an item to an organization.'

# confirm
complete -c bw -n __fish_no_subcommand -a confirm -d 'Confirm an object to the organization.'
complete -c bw -n '__fish_subcommand_is confirm' -a org-member
complete -c bw -n '__fish_subcommand_satisfies confirm' -l organizationid -d 'Organization id for an organization object.'

# import
complete -c bw -n __fish_no_subcommand -a import -d 'Import vault data from a file.'
complete -c bw -n '__fish_subcommand_is import' -a '1password1pif 1passwordmaccsv 1passwordwincsv ascendocsv avastcsv avastjson aviracsv bitwardencsv bitwardenjson blackberrycsv blurcsv buttercupcsv chromecsv clipperzhtml codebookcsv dashlanejson encryptrcsv enpasscsv enpassjson firefoxcsv fsecurefsk gnomejson kasperskytxt keepass2xml keepassxcsv keepercsv lastpasscsv logmeoncecsv meldiumcsv msecurecsv mykicsv nordpasscsv operacsv padlockcsv passboltcsv passkeepcsv passmanjson passpackcsv passwordagentcsv passwordbossjson passworddragonxml passwordwallettxt pwsafexml remembearcsv roboformcsv safaricsv safeincloudxml saferpasscsv securesafecsv splashidcsv stickypasswordxml truekeycsv upmcsv vivaldicsv yoticsv zohovaultcsv'
complete -c bw -n '__fish_subcommand_is import 1password1pif' -F
complete -c bw -n '__fish_subcommand_is import 1passwordmaccsv' -F
complete -c bw -n '__fish_subcommand_is import 1passwordwincsv' -F
complete -c bw -n '__fish_subcommand_is import ascendocsv' -F
complete -c bw -n '__fish_subcommand_is import avastcsv' -F
complete -c bw -n '__fish_subcommand_is import avastjson' -F
complete -c bw -n '__fish_subcommand_is import aviracsv' -F
complete -c bw -n '__fish_subcommand_is import bitwardencsv' -F
complete -c bw -n '__fish_subcommand_is import bitwardenjson' -F
complete -c bw -n '__fish_subcommand_is import blackberrycsv' -F
complete -c bw -n '__fish_subcommand_is import blurcsv' -F
complete -c bw -n '__fish_subcommand_is import buttercupcsv' -F
complete -c bw -n '__fish_subcommand_is import chromecsv' -F
complete -c bw -n '__fish_subcommand_is import clipperzhtml' -F
complete -c bw -n '__fish_subcommand_is import codebookcsv' -F
complete -c bw -n '__fish_subcommand_is import dashlanejson' -F
complete -c bw -n '__fish_subcommand_is import encryptrcsv' -F
complete -c bw -n '__fish_subcommand_is import enpasscsv' -F
complete -c bw -n '__fish_subcommand_is import enpassjson' -F
complete -c bw -n '__fish_subcommand_is import firefoxcsv' -F
complete -c bw -n '__fish_subcommand_is import fsecurefsk' -F
complete -c bw -n '__fish_subcommand_is import gnomejson' -F
complete -c bw -n '__fish_subcommand_is import kasperskytxt' -F
complete -c bw -n '__fish_subcommand_is import keepass2xml' -F
complete -c bw -n '__fish_subcommand_is import keepassxcsv' -F
complete -c bw -n '__fish_subcommand_is import keepercsv' -F
complete -c bw -n '__fish_subcommand_is import lastpasscsv' -F
complete -c bw -n '__fish_subcommand_is import logmeoncecsv' -F
complete -c bw -n '__fish_subcommand_is import meldiumcsv' -F
complete -c bw -n '__fish_subcommand_is import msecurecsv' -F
complete -c bw -n '__fish_subcommand_is import mykicsv' -F
complete -c bw -n '__fish_subcommand_is import nordpasscsv' -F
complete -c bw -n '__fish_subcommand_is import operacsv' -F
complete -c bw -n '__fish_subcommand_is import padlockcsv' -F
complete -c bw -n '__fish_subcommand_is import passboltcsv' -F
complete -c bw -n '__fish_subcommand_is import passkeepcsv' -F
complete -c bw -n '__fish_subcommand_is import passmanjson' -F
complete -c bw -n '__fish_subcommand_is import passpackcsv' -F
complete -c bw -n '__fish_subcommand_is import passwordagentcsv' -F
complete -c bw -n '__fish_subcommand_is import passwordbossjson' -F
complete -c bw -n '__fish_subcommand_is import passworddragonxml' -F
complete -c bw -n '__fish_subcommand_is import passwordwallettxt' -F
complete -c bw -n '__fish_subcommand_is import pwsafexml' -F
complete -c bw -n '__fish_subcommand_is import remembearcsv' -F
complete -c bw -n '__fish_subcommand_is import roboformcsv' -F
complete -c bw -n '__fish_subcommand_is import safaricsv' -F
complete -c bw -n '__fish_subcommand_is import safeincloudxml' -F
complete -c bw -n '__fish_subcommand_is import saferpasscsv' -F
complete -c bw -n '__fish_subcommand_is import securesafecsv' -F
complete -c bw -n '__fish_subcommand_is import splashidcsv' -F
complete -c bw -n '__fish_subcommand_is import stickypasswordxml' -F
complete -c bw -n '__fish_subcommand_is import truekeycsv' -F
complete -c bw -n '__fish_subcommand_is import upmcsv' -F
complete -c bw -n '__fish_subcommand_is import vivaldicsv' -F
complete -c bw -n '__fish_subcommand_is import yoticsv' -F
complete -c bw -n '__fish_subcommand_is import zohovaultcsv' -F
complete -c bw -n '__fish_subcommand_satisfies import' -l formats -d 'List formats'
complete -c bw -n '__fish_subcommand_satisfies import' -l organizationid -d 'ID of the organization to import to.'

# export
complete -c bw -n __fish_no_subcommand -a export -d 'Export vault data to a CSV, JSON or ZIP file.'
complete -c bw -n '__fish_subcommand_satisfies export' -l output -a '(ls -A)' -d 'Output directory or filename.'
complete -c bw -n '__fish_subcommand_satisfies export' -l format -a 'csv json encrypted_json' -d 'Export file format.'
complete -c bw -n '__fish_subcommand_satisfies export' -l password -d 'Use password to encrypt instead of your Bitwarden account encryption key. Only applies to the encrypted_json format.'
complete -c bw -n '__fish_subcommand_satisfies export' -l organizationid -d 'Organization id for an organization.'

# share (deprecated)
complete -c bw -n __fish_no_subcommand -a share -d '--DEPRECATED-- Move an item to an organization.'

# send
complete -c bw -n __fish_no_subcommand -a send -d 'Work with Bitwarden sends. A Send can be quickly created using this command or subcommands can be used to fine-tune the Send'
complete -c bw -n '__fish_subcommand_satisfies send' -F
complete -c bw -n '__fish_subcommand_satisfies send' -s f -l file -d 'Specifies that <data> is a filepath'
complete -c bw -n '__fish_subcommand_satisfies send' -s d -l deleteInDays -d 'The number of days in the future to set deletion date, defaults to 7'
complete -c bw -n '__fish_subcommand_satisfies send' -s a -l maxAccessCount -d 'The amount of max possible accesses.'
complete -c bw -n '__fish_subcommand_satisfies send' -l hidden -d 'Hide <data> in web by default. Valid only if --file is not set.'
complete -c bw -n '__fish_subcommand_satisfies send' -s n -l name -d 'The name of the Send. Defaults to a guid for text Sends and the filename for files.'
complete -c bw -n '__fish_subcommand_satisfies send' -l notes -d 'Notes to add to the Send.'
complete -c bw -n '__fish_subcommand_satisfies send' -l fullObject -d 'Specifies that the full Send object should be returned rather than just the access url.'

# send subcommands
complete -c bw -n '__fish_subcommand_is send' -a list -d 'List all the Sends owned by you'
complete -c bw -n '__fish_subcommand_is send' -a template -d 'Get json templates for send objects'
complete -c bw -n '__fish_subcommand_is send' -a get -d 'Get Sends owned by you.'
complete -c bw -n '__fish_subcommand_is send' -a receive -d 'Access a Bitwarden Send from a url'
complete -c bw -n '__fish_subcommand_is send' -a create -d 'create a Send'
complete -c bw -n '__fish_subcommand_is send' -a edit -d 'edit a Send'
complete -c bw -n '__fish_subcommand_is send' -a remove-password -d 'removes the saved password from a Send.'
complete -c bw -n '__fish_subcommand_is send' -a delete -d 'delete a Send'

# send get
complete -c bw -n '__fish_subcommand_satisfies send get' -l output -a '(ls -A)' -d 'Output directory or filename for attachment.'
complete -c bw -n '__fish_subcommand_satisfies send get' -l text -d 'Specifies to return the text content of a Send'

# send receive
complete -c bw -n '__fish_subcommand_satisfies send receive' -l password -d 'Password needed to access the Send.'
complete -c bw -n '__fish_subcommand_satisfies send receive' -l passwordenv -a '(set -nx)' -d 'Environment variable storing the Send\'s password'
complete -c bw -n '__fish_subcommand_satisfies send receive' -l passwordfile -a '(ls -A)' -d 'Path to a file containing the Sends password as its first line'
complete -c bw -n '__fish_subcommand_satisfies send receive' -l obj -d 'Return the Send\'s json object rather than the Send\'s content'
complete -c bw -n '__fish_subcommand_satisfies send receive' -l output -a '(ls -A)' -d 'Specify a file path to save a File-type Send to'

# send create
complete -c bw -n '__fish_subcommand_satisfies send create' -l file -a '(ls -A)' -d 'file to Send. Can also be specified in parent\'s JSON.'
complete -c bw -n '__fish_subcommand_satisfies send create' -l text -d 'text to Send. Can also be specified in parent\'s JSON.'
complete -c bw -n '__fish_subcommand_satisfies send create' -l hidden -d 'text hidden flag. Valid only with the --text option.'
complete -c bw -n '__fish_subcommand_satisfies send create' -l password -d 'optional password to access this Send. Can also be specified in JSON'

# send edit
complete -c bw -n '__fish_subcommand_satisfies send edit' -l itemid -d 'Overrides the itemId provided in [encodedJson]'

# receive
complete -c bw -n __fish_no_subcommand -a receive -d 'Access a Bitwarden Send from a url'
complete -c bw -n '__fish_subcommand_satisfies receive' -l password -d 'Password needed to access the Send.'
complete -c bw -n '__fish_subcommand_satisfies receive' -l passwordenv -a '(set -nx)' -d 'Environment variable storing the Send\'s password'
complete -c bw -n '__fish_subcommand_satisfies receive' -l passwordfile -a '(ls -A)' -d 'Path to a file containing the Sends password as its first line'
complete -c bw -n '__fish_subcommand_satisfies receive' -l obj -d 'Return the Send\'s json object rather than the Send\'s content'
complete -c bw -n '__fish_subcommand_satisfies receive' -l output -a '(ls -A)' -d 'Specify a file path to save a File-type Send to'

# device-approval
complete -c bw -n __fish_no_subcommand -a device-approval -d 'Manage device approval requests sent to organizations that use SSO with trusted devices.'
complete -c bw -n '__fish_subcommand_is device-approval' -a list -d 'List all pending requests for an organization'
complete -c bw -n '__fish_subcommand_is device-approval' -a approve -d 'Approve a pending request'
complete -c bw -n '__fish_subcommand_is device-approval' -a approve-all -d 'Approve all pending requests for an organization'
complete -c bw -n '__fish_subcommand_is device-approval' -a deny -d 'Deny a pending request'
complete -c bw -n '__fish_subcommand_is device-approval' -a deny-all -d 'Deny all pending requests for an organization'

# device-approval options
complete -c bw -n '__fish_subcommand_satisfies device-approval list' -l organizationid -d 'The organization id (required)'
complete -c bw -n '__fish_subcommand_satisfies device-approval approve' -l organizationid -d 'The organization id (required)'
complete -c bw -n '__fish_subcommand_satisfies device-approval approve-all' -l organizationid -d 'The organization id (required)'
complete -c bw -n '__fish_subcommand_satisfies device-approval deny' -l organizationid -d 'The organization id (required)'
complete -c bw -n '__fish_subcommand_satisfies device-approval deny-all' -l organizationid -d 'The organization id (required)'

# serve
complete -c bw -n __fish_no_subcommand -a serve -d 'Start a RESTful API webserver.'
complete -c bw -n '__fish_subcommand_satisfies serve' -l hostname -d 'The hostname to bind your API webserver to.'
complete -c bw -n '__fish_subcommand_satisfies serve' -l port -d 'The port to run your API webserver on.'
complete -c bw -n '__fish_subcommand_satisfies serve' -l disable-origin-protection -d 'If set, allows requests with origin header. Warning, this option exists for backwards compatibility reasons and exposes your environment to known CSRF attacks.'

# help
complete -c bw -n __fish_no_subcommand -a help -d 'display help for command'
complete -c bw -n '__fish_subcommand_is help' -a 'sdk-version login logout lock unlock sync generate encode config update completion status list get create edit delete restore move confirm import export share send receive device-approval serve'
