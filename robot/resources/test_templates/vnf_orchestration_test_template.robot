*** Settings ***
Documentation	  This test template encapsulates the VNF Orchestration use case.

Resource        ../vid/create_service_instance.robot
Resource        ../vid/vid_interface.robot
Resource        ../aai/service_instance.robot
Resource        ../vid/create_vid_vnf.robot
Resource        ../vid/teardown_vid.robot
Resource        ../sdngc_interface.robot
Resource        model_test_template.robot

Resource        ../aai/create_zone.robot
Resource        ../aai/create_customer.robot
Resource        ../aai/create_complex.robot
Resource        ../aai/create_tenant.robot
Resource        ../aai/create_service.robot
Resource        ../openstack/neutron_interface.robot
Resource        ../heatbridge.robot


Library         OpenstackLibrary
Library 	    ExtendedSelenium2Library
Library	        UUID
Library	        Collections
Library	        String



*** Variables ***

#**************** TEST CASE VARIABLES **************************
${TENANT_NAME}    tenant-demo
${TENANT_ID}    tenant-demo
${REGIONS}
${CUSTOMER_NAME}
${STACK_NAME}
${STACK_NAMES}
${SERVICE}
${VVG_SERVER_ID}
${SERVICE_INSTANCE_ID}

*** Keywords ***
Orchestrate VNF Template
    [Documentation]   Use openECOMP to Orchestrate a service.
    [Arguments]    ${customer_name}    ${service}    ${product_family}    ${tenant}
    Orchestrate VNF   ${customer_name}    ${service}    ${product_family}    ${tenant}
    Delete VNF

Orchestrate VNF
    [Documentation]   Use openECOMP to Orchestrate a service.
    [Arguments]    ${customer_name}    ${service}    ${product_family}    ${tenant}
    # For Azure Service Cloud Region is specific as mentioned in integrated_robot_properties file..
    # thus modification  for lcp_region is needed
    ${lcp_region}=    Run Keyword If    "${service}" != "AzurevFW" and "${service}" != "AzurevDNS"    Get Openstack Region
    ...    ELSE    set variable      ${AZURE_CLOUD_REGION}
    ${uuid}=    Generate UUID
    Set Test Variable    ${CUSTOMER_NAME}    ${customer_name}_${uuid}
    Set Test Variable    ${SERVICE}    ${service}
    ${list}=    Create List
    Set Test Variable    ${STACK_NAMES}   ${list}
    ${service_name}=    Catenate    Service_Ete_Name${uuid}
    ${service_type}=    Set Variable    ${service}

    # For Azure Service "Cloud Owner and Cloud Region" is specific as mentioned in integrated_robot_properties file..
    # Thus modification in create customer for vnf  request is needed..
    Log to Console    Customer_Created=${CUSTOMER_NAME}
    Run Keyword If    "${service}" == "AzureVFW" or "${service}" == "AzurevDNS"    Create Customer For VNF    ${CUSTOMER_NAME}    ${CUSTOMER_NAME}    INFRA    ${service_type}    ${AZURE_CLOUD_OWNER}
    ...    ELSE    Create Customer For VNF    ${CUSTOMER_NAME}    ${CUSTOMER_NAME}    INFRA    ${service_type}    ${GLOBAL_AAI_CLOUD_OWNER}
    ${service_model_type}     ${vnf_type}    ${vf_modules}   ${catalog_resources}=    Model Distribution For Directory    ${service}
    sleep    30s
    Run Keyword If   '${service}' == 'vVG'    Create VVG Server    ${uuid}
    Setup Browser
    Login To VID GUI
    ${service_instance_id}=   Wait Until Keyword Succeeds    300s   5s    Create VID Service Instance    ${customer_name}    ${service_model_type}    ${service}     ${service_name}
    Set Test Variable   ${SERVICE_INSTANCE_ID}   ${service_instance_id}
    Validate Service Instance    ${service_instance_id}    ${service}      ${customer_name}
    Log to Console    VID_Service_Instance_Created=${service_instance_id}
    ${vnflist}=   Get From Dictionary    ${GLOBAL_SERVICE_VNF_MAPPING}    ${service}
    ${vnfmap}=    Create Dictionary

    # For vFWLC closed loop test generic-vnf-name (${vnf_name} will be used as the FWL hostname so we
    # now need to make it be a valid hostname

    # In case of Azure Services, Methods such as Execute Heatbridge and Validate VF Module which uses Openstack are not needed
    :for   ${vnf}   in   @{vnflist}
    \   ${shortuuid}=   Catenate   ${uuid}
    \   ${shortuuid}=   Replace String    ${shortuuid}    -   ${SPACE}
    \   ${shortuuid}=   Get Substring    ${shortuuid}    -8
    \   ${vnf_name}=    Catenate    ${vnf}${shortuuid}
    \   ${vnf_name}=    Convert To Lowercase    ${vnf_name}
    \   ${vf_module_name}=    Catenate    Vfmodule_Ete_${vnf}_${uuid}
    \   ${vnf_type}=   Get VNF Type   ${catalog_resources}   ${vnf}
    \   ${vf_module}=    Get VF Module    ${catalog_resources}   ${vnf}
    \   Append To List   ${STACK_NAMES}   ${vf_module_name}
    \    Log to Console    VNF_Currently_Being_Created_is=${vnf_name}
    \    Run Keyword If    "AzurevPKG"=="${vnf}"    Restart Browser
    \   Wait Until Keyword Succeeds    300s   5s    Create VID VNF    ${service_instance_id}    ${vnf_name}    ${product_family}    ${lcp_region}    ${tenant}    ${vnf_type}   ${CUSTOMER_NAME}
    \   ${vf_module_type}   ${closedloop_vf_module}=   Preload Vnf    ${service_instance_id}   ${vnf_name}   ${vnf_type}   ${vf_module_name}    ${vf_module}    ${vnf}    ${uuid}
    \   ${vf_module_id}=   Create VID VNF module    ${service_instance_id}    ${vf_module_name}    ${lcp_region}    ${tenant}     ${vf_module_type}   ${CUSTOMER_NAME}   ${vnf_name}
    \   ${generic_vnf}=   Validate Generic VNF    ${vnf_name}    ${vnf_type}    ${service_instance_id}
    \   VLB Closed Loop Hack   ${service}   ${generic_vnf}   ${closedloop_vf_module}
    \   Set Test Variable    ${STACK_NAME}   ${vf_module_name}
    \   Append To List   ${STACK_NAMES}   ${STACK_NAME}
    \   Run Keyword If    "${service}"!="AzurevFW" and "${service}"!="AzurevDNS"    Execute Heatbridge    ${vf_module_name}    ${service_instance_id}    ${vnf}
    \   Run Keyword If    "${service}"!="AzurevFW" and "${service}"!="AzurevDNS"    Validate VF Module      ${vf_module_name}    ${vnf}
    \   Set To Dictionary    ${vnfmap}    ${vnf}=${vf_module_name}
    [Return]     ${vnfmap}    ${service}


Restart Browser
    [Documentation]    Restarts the browser session for Adding AzurevFW VF Module to prevent timeout
    Setup Browser
    Login To VID GUI


Get VNF Type
    [Documentation]    To support services with multiple VNFs, we need to dig the vnf type out of the SDC catalog resources to select in the VID UI
    [Arguments]   ${resources}   ${vnf}
    ${cr}=   Get Catalog Resource    ${resources}    ${vnf}
    ${vnf_type}=   Get From Dictionary   ${cr}   name
    [Return]   ${vnf_type}

Get VF Module
    [Documentation]    To support services with multiple VNFs, we need to dig the vnf type out of the SDC catalog resources to select in the VID UI
    [Arguments]   ${resources}   ${vnf}
    ${cr}=   Get Catalog Resource    ${resources}    ${vnf}
    ${vf_module}=    Find Element In Array    ${cr['groups']}    type    org.openecomp.groups.VfModule
    [Return]  ${vf_module}

Get Catalog Resource
    [Documentation]    To support services with multiple VNFs, we need to dig the vnf type out of the SDC catalog resources to select in the VID UI
    [Arguments]   ${resources}   ${vnf}

    ${base_name}=  Get Name Pattern   ${vnf}
    ${keys}=    Get Dictionary Keys    ${resources}

    :for   ${key}   in    @{keys}
    \    ${cr}=   Get From Dictionary    ${resources}    ${key}
    \    ${status}   ${value}=   Run Keyword and Ignore Error   Get Catalog Resource Info from Heat Artifact   ${cr['allArtifacts']}   ${base_name}
    \    Return From Keyword If   '${status}' == 'PASS'    ${cr}
    Fail    Unable to find catalog resource for ${vnf} ${base_name}

Get Catalog Resource Info from Heat Artifact
    [Documentation]    Need to look though the list of heats.... heat1, heat2...
    [Arguments]   ${artifacts}   ${base_name}
    ${keys}=   Get Dictionary Keys    ${artifacts}
    ${heatArtifacts}=   Create List
    :for   ${key}   in    @{keys}
    \    Run Keyword If    'heat' in '${key}' and 'env' not in '${key}'   Append To List   ${heatArtifacts}   ${artifacts['${key}']}
    \    Run Keyword If    'azurevsnk' in '${key}' and 'env' not in '${key}'   Append To List   ${heatArtifacts}   ${artifacts['${key}']}
    \    Run Keyword If    'azurevpkg' in '${key}' and 'env' not in '${key}'   Append To List   ${heatArtifacts}   ${artifacts['${key}']}
    \    Run Keyword If    'azurevdns' in '${key}' and 'env' not in '${key}'   Append To List   ${heatArtifacts}   ${artifacts['${key}']}
    :for   ${ha}   in   @{heatArtifacts}
    \    Return From Keyword If   '${base_name}' in '${ha['artifactDisplayName']}'
    Fail   Unable to find ${base_name} in heatArtifacts

Get Name Pattern
    [Documentation]    To support services with multiple VNFs, we need to dig the vnf type out of the SDC catalog resources to select in the VID UI
    [Arguments]   ${vnf}
    ${list}=   Get From Dictionary    ${GLOBAL_SERVICE_TEMPLATE_MAPPING}   ${vnf}
    :for    ${dict}   in   @{list}
    \   ${base_name}=   Get From Dictionary    ${dict}    name_pattern
    \   Return From Keyword If   '${dict['isBase']}' == 'true'   ${base_name}
    Fail  Unable to locate base name pattern



Create Customer For VNF
    [Documentation]    VNF Orchestration Test setup....
    ...                Create Tenant if not exists, Create Customer, Create Service and related relationships
    [Arguments]    ${customer_name}    ${customer_id}    ${customer_type}    ${service_type}    ${cloud_owner}
    ${cloud_region_id}=    Run Keyword If    "${service_type}" != "AzurevFW" and "${service_type}" != "AzurevDNS"    Get Openstack Region
    ...    ELSE    set variable      ${AZURE_CLOUD_REGION}
    ${cloud_owner}=    Run Keyword If    "${service_type}" == "AzurevFW" or "${service_type}" == "AzurevDNS"    set variable      ${AZURE_CLOUD_OWNER}
    ...    ELSE    set variable      ${GLOBAL_AAI_CLOUD_OWNER}
    Create Service If Not Exists    ${service_type}
    ${resp}=    Create Customer    ${customer_name}    ${customer_id}    ${customer_type}    ${service_type}   ${cloud_owner}  ${cloud_region_id}    ${TENANT_ID}
	Should Be Equal As Strings 	${resp} 	201

Setup Orchestrate VNF
    [Documentation]    Called before each test case to ensure tenant and region data
    ...                required by the Orchstrate VNF exists in A&AI
    [Arguments]        ${cloud_owner}  ${cloud_type}    ${owner_defined_type}    ${cloud_region_version}    ${cloud_zone}
    Initialize Tenant From Openstack
    Initialize Regions From Openstack
    :FOR    ${region}    IN    @{REGIONS}
    \    Inventory Tenant If Not Exists    ${cloud_owner}  ${region}  ${cloud_type}    ${owner_defined_type}    ${cloud_region_version}    ${cloud_zone}    ${TENANT_ID}    ${TENANT_NAME}
    Inventory Zone If Not Exists
    Inventory Complex If Not Exists    ${GLOBAL_AAI_COMPLEX_NAME}   ${GLOBAL_AAI_PHYSICAL_LOCATION_ID}   ${GLOBAL_AAI_CLOUD_OWNER}   ${GLOBAL_INJECTED_REGION}   ${GLOBAL_AAI_CLOUD_OWNER_DEFINED_TYPE}
    Log   Orchestrate VNF setup complete

Initialize Tenant From Openstack
    [Documentation]    Initialize the tenant test variables
    Run Openstack Auth Request    auth
    ${tenants}=    Get Current Openstack Tenant     auth
    ${tenant_name}=    Evaluate    $tenants.get("name")
    ${tenant_id}=     Evaluate    $tenants.get("id")
    Set Test Variable	${TENANT_NAME}   ${tenant_name}
    Set Test Variable	${TENANT_ID}     ${tenant_id}

Initialize Regions From Openstack
    [Documentation]    Initialize the regions test variable
    Run Openstack Auth Request    auth
    ${regs}=    Get Openstack Regions    auth
    Set Test Variable	${REGIONS}     ${regs}

Create VVG Server
    [Documentation]    For the VolumeGroup test case, create a server to attach the volume group to be orchestrated.
    [Arguments]    ${uuid}
    Run Openstack Auth Request    auth
    ${vvg_server_name}=    Catenate   vVG_${uuid}
    ${server}=   Add Server For Image Name  auth    ${vvg_server_name}   ${GLOBAL_INJECTED_UBUNTU_1404_IMAGE}   ${GLOBAL_INJECTED_VM_FLAVOR}   ${GLOBAL_INJECTED_PUBLIC_NET_ID}
    ${server}=       Get From Dictionary   ${server}   server
    ${server_id}=    Get From Dictionary   ${server}   id
    Set Test Variable    ${VVG_SERVER_ID}   ${server_id}
    ${vvg_params}=    Get VVG Preload Parameters
    Set To Dictionary   ${vvg_params}   nova_instance   ${server_id}
    Wait for Server to Be Active    auth    ${server_id}

Get VVG Preload Parameters
    [Documentation]   Get preload parameters for the VVG test case so we can include
    ...               the nova_instance id of the attached server
    ${test_dict}=    Get From Dictionary    ${GLOBAL_PRELOAD_PARAMETERS}    Vnf-Orchestration
    ${vvg_params}   Get From Dictionary    ${test_dict}    vvg_preload.template
    [Return]    ${vvg_params}

Delete VNF
    [Documentation]    Called at the end of a test case to tear down the VNF created by Orchestrate VNF
    ${lcp_region}=   Get Openstack Region
    Teardown VVG Server
    Teardown VLB Closed Loop Hack
    Run Keyword and Ignore Error   Teardown VID   ${SERVICE_INSTANCE_ID}   ${lcp_region}   ${TENANT_NAME}   ${CUSTOMER_NAME}
    Log    VNF Deleted

Teardown VNF
    [Documentation]    Called at the end of a test case to tear down the VNF created by Orchestrate VNF
    Run Keyword If   '${TEST STATUS}' == 'PASS'   Teardown Model Distribution
    Run Keyword If   '${TEST STATUS}' == 'PASS'   Clean A&AI Inventory
    Close All Browsers
    Log    Teardown VNF implemented for successful tests only

Teardown VVG Server
    [Documentation]   Teardown the server created as a place to mount the Volume Group.
    Return From Keyword if   '${VVG_SERVER_ID}' == ''
    Delete Server   auth   ${VVG_SERVER_ID}
    Wait for Server To Be Deleted    auth    ${VVG_SERVER_ID}
    ${vvg_params}=    Get VVG Preload Parameters
    Remove from Dictionary   ${vvg_params}   nova_instance
    Log    Teardown VVG Server Completed

Teardown Stack
    [Documentation]    OBSOLETE - Called at the end of a test case to tear down the Stack created by Orchestrate VNF
    [Arguments]   ${stack}
    Run Openstack Auth Request    auth
    ${stack_info}=    Get Stack Details    auth    ${stack}
    Log    ${stack_info}
    ${stack_id}=    Get From Dictionary    ${stack_info}    id
    ${key_pair_status}   ${keypair_name}=   Run Keyword And Ignore Error   Get From Dictionary    ${stack_info}    key_name
    Delete Openstack Stack      auth    ${stack}    ${stack_id}
    Log    Deleted ${stack} ${stack_id}
    Run Keyword If   '${key_pair_status}' == 'PASS'   Delete Openstack Keypair    auth    ${keypair_name}
    Teardown VLB Closed Loop Hack

Clean A&AI Inventory
    [Documentation]    Clean up Tenant in A&AI, Create Customer, Create Service and related relationships
    Delete Customer    ${CUSTOMER_NAME}
