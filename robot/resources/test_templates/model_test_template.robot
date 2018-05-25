*** Settings ***
Documentation     The main interface for interacting with ASDC. It handles low level stuff like managing the http request library and DCAE required fields
Library           OperatingSystem
Library            ArchiveLibrary
Library           Collections
Library           String
Library           base64_encrypt.py
Resource          ../asdc_interface.robot

Variables       ../../assets/service_mappings.py

*** Variables ***
${ASDC_BASE_PATH}    /sdc1
${ASDC_DESIGNER_PATH}    /proxy-designer1#/dashboard
${ASDC_ASSETS_DIRECTORY}    ${GLOBAL_HEAT_TEMPLATES_FOLDER}
${ASDC_ASSETS_DIRECTORY_AZURE}    ${AZURE_CSAR_TEMPLATES_FOLDER}
${ASDC_ZIP_DIRECTORY}    ${ASDC_ASSETS_DIRECTORY}/temp
${ASDC_ZIP_DIRECTORY_AZURE}    ${ASDC_ASSETS_DIRECTORY_AZURE}/temp

#***************** Test Case Variables *********************
${CATALOG_RESOURCE_IDS}
${CATALOG_SERVICE_ID}

*** Keywords ***

Model Distribution For Directory
    [Documentation]    Initiates Model Distribution and Gathers the required files- csars or zips
    [Arguments]    ${service}   ${catalog_service_name}=
    ${directory_list}=    Get From Dictionary    ${GLOBAL_SERVICE_FOLDER_MAPPING}    ${service}
    ${ziplist}=    Run Keyword If    "${service}"=="AzurevFW" or "${service}" == "AzurevDNS"    Create Csar    ${directory_list}
    ...    ELSE    Create Zip    ${directory_list}
    ${catalog_service_name}    ${catalog_resource_name}    ${vf_modules}    ${catalog_resource_ids}   ${catalog_service_id}   ${catalog_resources}   Distribute Model From ASDC    ${ziplist}    ${catalog_service_name}
    Set Test Variable   ${CATALOG_RESOURCE_IDS}   ${catalog_resource_ids}
    Set Test Variable   ${CATALOG_SERVICE_ID}   ${catalog_service_id}
    Set Test Variable   ${CATALOG_RESOURCES}   ${catalog_resources}
    [Return]    ${catalog_service_name}    ${catalog_resource_name}    ${vf_modules}   ${catalog_resources}


Create Zip
    [Documentation]    Creates zip file for heat based model distribution
    [Arguments]    ${directory_list}
    ${ziplist}=    Create List
    :for   ${directory}    in    @{directory_list}
		\    ${zipname}=   Replace String    ${directory}    /    _
		\    ${zip}=    Catenate    ${ASDC_ZIP_DIRECTORY}/${zipname}.zip
        \    ${folder}=    Catenate    ${ASDC_ASSETS_DIRECTORY}/${directory}
		\    OperatingSystem.Create Directory    ${ASDC_ASSETS_DIRECTORY}/temp
		\    Create Zip From Files In Directory        ${folder}    ${zip}
		\    Append To List    ${ziplist}    ${zip}
    [Return]    ${ziplist}


Create Csar
    [Documentation]    Creates csar file for csar based model distribution
    [Arguments]    ${directory_list}
    ${ziplist}=    Create List
    :for   ${directory}    in    @{directory_list}
    \    ${zipname}=   Replace String    ${directory}    /    _
    \    ${zip}=    Catenate    ${ASDC_ZIP_DIRECTORY_AZURE}/${zipname}.zip
    \    ${folder}=    Catenate    ${ASDC_ASSETS_DIRECTORY_AZURE}/${directory}
    \    OperatingSystem.Create Directory    ${ASDC_ASSETS_DIRECTORY_AZURE}/temp
    \    create zip from files in directory subdirectory        ${folder}    ${zip}    sub_directories=True
    \    rename zip    ${ASDC_ASSETS_DIRECTORY_AZURE}/temp/    ${zip}    ${zipname}.csar
    \    Append To List    ${ziplist}    ${ASDC_ZIP_DIRECTORY_AZURE}/${zipname}.csar
    [Return]    ${ziplist}


Teardown Model Distribution
    [Documentation]    Clean up at the end of the test
    Log   ${CATALOG_SERVICE_ID} ${CATALOG_RESOURCE_IDS}
    Teardown Models    ${CATALOG_SERVICE_ID}   ${CATALOG_RESOURCE_IDS}

Teardown Models
    [Documentation]    Clean up at the end of the test
    [Arguments]     ${catalog_service_id}    ${catalog_resource_ids}
    Return From Keyword If    '${catalog_service_id}' == ''
    :for    ${catalog_resource_id}   in   @{catalog_resource_ids}
    \   ${resourece_json}=   Mark ASDC Catalog Resource Inactive    ${catalog_resource_id}
    ${service_json}=   Mark ASDC Catalog Service Inactive    ${catalog_service_id}
    ${services_json}=   Delete Inactive ASDC Catalog Services
    ${resources_json}=    Delete Inactive ASDC Catalog Resources