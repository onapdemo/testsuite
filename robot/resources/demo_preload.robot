*** Settings ***
Documentation	  This test template encapsulates the VNF Orchestration use case.

Resource        test_templates/model_test_template.robot
Resource        test_templates/vnf_orchestration_test_template.robot
Resource        asdc_interface.robot
Resource        vid/vid_interface.robot
Resource        policy_interface.robot
Resource        msb_interface.robot
Resource      aai/create_tenant.robot
Library	        UUID
Library	        Collections
Library         OperatingSystem
Library         HttpLibrary.HTTP
Library         ExtendedSelenium2Library
Library         RequestsLibrary
Library         JSONLibrary

*** Variables ***

${ADD_DEMO_CUSTOMER_BODY}   robot/assets/templates/aai/add_demo_customer.template
${AAI_INDEX_PATH}     /aai/v8
${VF_MODULES_NAME}     _Demo_VFModules.json
${FILE_CACHE}    /share/
${DEMO_PREFIX}   demo
${CLOUD_ESR_TEMPLATE}    robot/assets/templates/aai/create_cloud_esr.template
${CLOUD_ESR_API}    api/aai-esr-server/v1/vims
${TENANT_NAME}
${cloud_owner}

*** Keywords ***
Load Customer And Models
    [Documentation]   Use openECOMP to Orchestrate a service.
    [Arguments]    ${customer_name}
    Load Customer  ${customer_name}
    Load Models  ${customer_name}

Load Customer
    [Documentation]   Use openECOMP to Orchestrate a service.
    [Arguments]    ${customer_name}
    Setup Orchestrate VNF   ${GLOBAL_AAI_CLOUD_OWNER}   SharedNode    OwnerType    v1    CloudZone
    Set Test Variable    ${CUSTOMER_NAME}    ${customer_name}
    ${region}=   Get Openstack Region
    Create Customer For VNF Demo    ${CUSTOMER_NAME}    ${CUSTOMER_NAME}    INFRA    ${GLOBAL_AAI_CLOUD_OWNER}    ${region}   ${TENANT_ID}

Load Models
    [Documentation]   Use openECOMP to Orchestrate a service.
    [Arguments]    ${customer_name}
    Set Test Variable    ${CUSTOMER_NAME}    ${customer_name}
    ${status}   ${value}=   Run Keyword And Ignore Error   Distribute Model   AzurevFW   ${DEMO_PREFIX}_AzurevFW
    #${status}   ${value}=   Run Keyword And Ignore Error   Distribute Model   AzurevDNS   ${DEMO_PREFIX}_AzurevDNS
    #${status}   ${value}=   Run Keyword And Ignore Error   Distribute Model   vFWCL   ${DEMO_PREFIX}VFWCL
    #${status}   ${value}=   Run Keyword And Ignore Error   Distribute Model   vLB   ${DEMO_PREFIX}VLB
    #${status}   ${value}=   Run Keyword And Ignore Error   Distribute Model   vCPE   ${DEMO_PREFIX}VCPE
    ##${status}   ${value}=   Run Keyword And Ignore Error   Distribute Model   vIMS   ${DEMO_PREFIX}VIMS

Distribute Model
    [Arguments]   ${service}   ${modelName}
    ${service_model_type}     ${vnf_type}    ${vf_modules}=   Model Distribution For Directory    ${service}   ${modelName}

Create Customer For VNF Demo
    [Documentation]    Create demo customer for the demo
    [Arguments]    ${customer_name}   ${customer_id}   ${customer_type}    ${clouder_owner}    ${cloud_region_id}    ${tenant_id}
    Create Service If Not Exists    vFWCL
    Create Service If Not Exists    vLB
    Create Service If Not Exists    vCPE
    Create Service If Not Exists    vIMS
    ${data_template}=    OperatingSystem.Get File    ${ADD_DEMO_CUSTOMER_BODY}
    ${arguments}=    Create Dictionary    subscriber_name=${customer_name}    global_customer_id=${customer_id}    subscriber_type=${customer_type}     cloud_owner=${clouder_owner}  cloud_region_id=${cloud_region_id}    tenant_id=${tenant_id}
    Set To Dictionary   ${arguments}       service1=vFWCL       service2=vLB   service3=vCPE   service4=vIMS
    ${data}=	Fill JSON Template    ${data_template}    ${arguments}
    ${put_resp}=    Run A&AI Put Request     ${INDEX PATH}${ROOT_CUSTOMER_PATH}${customer_id}    ${data}
    ${status_string}=    Convert To String    ${put_resp.status_code}
    Should Match Regexp    ${status_string}    ^(200|201|412)$

Preload User Model
    [Documentation]   Preload the demo data for the passed VNF with the passed module name
    [Arguments]   ${vnf_name}   ${vf_module_name}    ${vnf_service}=default
    # Go to A&AI and get information about the VNF we need to preload
    ${status}  ${generic_vnf}=   Run Keyword And Ignore Error   Get Service Instance    ${vnf_name}
    Run Keyword If   '${status}' == 'FAIL'   FAIL   VNF Name: ${vnf_name} is not found.
    ${vnf_type}=   Set Variable   ${generic_vnf['vnf-type']}
    ${invariantUUID}   ${service}   ${customer_id}   ${service_instance_id}=   Get Generic VNF Info    ${generic_vnf}

    ## Reuse for VFW policy update...
    ##${relationships}=   Set Variable   ${generic_vnf['relationship-list']['relationship']}
    ##${relationship_data}=    Get Relationship Data   ${relationships}
    ##${customer_id}=   Catenate
    ##:for    ${r}   in   @{relationship_data}
    ##\   ${service}=   Set Variab  le If    '${r['relationship-key']}' == 'service-subscription.service-type'   ${r['relationship-value']}    ${service}
    ##\   ${service_instance_id}=   Set Variable If    '${r['relationship-key']}' == 'service-instance.service-instance-id'   ${r['relationship-value']}   ${service_instance_id}
    ##\   ${customer_id}=    Set Variable If   '${r['relationship-key']}' == 'customer.global-customer-id'   ${r['relationship-value']}   ${customer_id}
    ##${invariantUUID}=   Get Persona Model Id     ${service_instance_id}    ${service}    ${customer_id}

    # We still need the vf module names. We can get them from VID using the persona_model_id (invariantUUID) from A&AI
    Setup Browser
    Login To VID GUI
    ${vf_modules}=   Get Module Names from VID    ${invariantUUID}
    ${vnf_service}=   Set Variable If   '${vnf_service}'=='default'   ${service}   ${vnf_service}
    ${vf_modules}=    Get The Selected Modules   ${vf_modules}   ${vnf_service}
    Log    ${generic_vnf}
    Log   ${service_instance_id},${vnf_name},${vnf_type},${vf_module_name},${vf_modules},${service}
    Preload Vnf    ${service_instance_id}   ${vnf_name}   ${vnf_type}   ${vf_module_name}    ${vf_modules}    ${vnf_service}    demo
    [Teardown]    Close All Browsers

Get Generic VNF Info
    [Documentation]   Grab some selected informastion from the generic vnf relationships
    [Arguments]   ${generic_vnf}
    ${relationships}=   Set Variable   ${generic_vnf['relationship-list']['relationship']}
    ${relationship_data}=    Get Relationship Data   ${relationships}
    ${customer_id}=   Catenate
    ${service_instance_id}=   Catenate
    ${service}=    Catenate
    :for    ${r}   in   @{relationship_data}
    \   ${service}=   Set Variable If    '${r['relationship-key']}' == 'service-subscription.service-type'   ${r['relationship-value']}    ${service}
    \   ${service_instance_id}=   Set Variable If    '${r['relationship-key']}' == 'service-instance.service-instance-id'   ${r['relationship-value']}   ${service_instance_id}
    \   ${customer_id}=    Set Variable If   '${r['relationship-key']}' == 'customer.global-customer-id'   ${r['relationship-value']}   ${customer_id}
    ${invariantUUID}=   Get Persona Model Id     ${service_instance_id}    ${service}    ${customer_id}
    [Return]   ${invariantUUID}   ${service}   ${customer_id}   ${service_instance_id}



Get The Selected Modules
    [Arguments]   ${vf_modules}   ${vnf_service}
    ${returnlist}   Create List
    ${list}=   Get From DIctionary   ${GLOBAL_SERVICE_TEMPLATE_MAPPING}   ${vnf_service}
    :for    ${map}   in   @{list}
    \    ${name}=   Get From Dictionary    ${map}    name_pattern
    \    Add To Module List   ${vf_modules}   ${name}   ${returnlist}
    [Return]    ${returnlist}

Add To Module List
    [Arguments]   ${vf_modules}   ${name}   ${returnlist}
    :for   ${map}   in   @{vf_modules}
    \    Run Keyword If   '${name}' in '${map['name']}'   Append To List    ${returnlist}   ${map}

Get Relationship Data
    [Arguments]   ${relationships}
    :for    ${r}   in   @{relationships}
    \     ${status}   ${relationship_data}   Run Keyword And Ignore Error    Set Variable   ${r['relationship-data']}
    \     Return From Keyword If    '${status}' == 'PASS'   ${relationship_data}


Get Generic VNF By ID
    [Arguments]   ${vnf_id}
    ${resp}=    Run A&AI Get Request      ${AAI_INDEX PATH}/network/generic-vnfs/generic-vnf?vnf-id=${vnf_id}
    Should Be Equal As Strings 	${resp.status_code} 	200
    [Return]   ${resp.json()}

Get Service Instance
    [Arguments]   ${vnf_name}
    ${resp}=    Run A&AI Get Request      ${AAI_INDEX PATH}/network/generic-vnfs/generic-vnf?vnf-name=${vnf_name}
    Should Be Equal As Strings 	${resp.status_code} 	200
    [Return]   ${resp.json()}

Get Persona Model Id
    [Documentation]    Query and Validates A&AI Service Instance
    [Arguments]    ${service_instance_id}    ${service_type}   ${customer_id}
    ${resp}=    Run A&AI Get Request      ${INDEX PATH}${CUSTOMER SPEC PATH}${customer_id}${SERVICE SUBSCRIPTIONS}${service_type}${SERVICE INSTANCE}${service_instance_id}
    ${persona_model_id}=   Get From DIctionary   ${resp.json()['service-instance'][0]}    model-invariant-id
    [Return]   ${persona_model_id}

APPC Mount Point
    [Arguments]   ${vf_module_name}
    Run Openstack Auth Request    auth
    ${status}   ${stack_info}=   Run Keyword and Ignore Error    Wait for Stack to Be Deployed    auth    ${vf_module_name}   timeout=120s
    Run Keyword if   '${status}' == 'FAIL'   FAIL   ${vf_module_name} Stack is not found
    ${stack_id}=    Get From Dictionary    ${stack_info}    id
    ${server_list}=    Get Openstack Servers    auth
    ${vnf_id}=    Get From Dictionary    ${stack_info}    vnf_id
    ${vpg_public_ip}=    Get Server Ip    ${server_list}    ${stack_info}   vpg_name_0    network_name=public
    ${vpg_oam_ip}=    Get From Dictionary    ${stack_info}    vpg_private_ip_1
    ${appc}=    Create Mount Point In APPC    ${vnf_id}    ${vpg_oam_ip}

Execute VFW Policy Update VNF Name
    [Arguments]   ${vnf_name}
    ${status}  ${generic_vnf}=   Run Keyword And Ignore Error   Get Service Instance    ${vnf_name}
    Run Keyword If   '${status}' == 'FAIL'   FAIL   VNF Name: ${vnf_name} is not found.
    ${invariantUUID}   ${service}   ${customer_id}   ${service_instance_id}=   Get Generic VNF Info    ${generic_vnf}
    Update vVFWCL Policy   ${invariantUUID}

Execute VFW Policy Update
    [Arguments]   ${resource_id}
    Update vVFWCL Policy   ${resource_id}

Instantiate VNF
    [Arguments]   ${service}
    Setup Orchestrate VNF    ${GLOBAL_AAI_CLOUD_OWNER}    SharedNode    OwnerType    v1    CloudZone
    ${stacknamemap}    ${service}=    Orchestrate VNF    DemoCust    ${service}   ${service}    ${TENANT_NAME}
    Save For Delete
    Log to Console   Customer Name=${CUSTOMER_NAME}
    ${stacks}=   Get Dictionary Values    ${stacknamemap}
    :for   ${stackname}   in   @{stacks}
    \   Log to Console   VNF Module Name=${stackname}

Instantiate AzureVNF
    [Documentation]    Instantiantes VNF on Microsoft Azure
    [Arguments]   ${service}
    Create Cloud If Not Exists    ${AZURE_CLOUD_OWNER}    ${AZURE_CLOUD_REGION}   ${AZURE_SUBSCRIPTION_ID}    ${AZURE_CLIENT_ID}    ${AZURE_CLIENT_SECRET}    ${AZURE_TENANT_ID}
    Set Test Variable    ${TENANT_ID}    tenant-demo
    Set Test Variable    ${TENANT_NAME}    tenant-demo
    Create Tenant If Not Exists    ${AZURE_CLOUD_OWNER}    ${AZURE_CLOUD_REGION}   ${TENANT_ID}    ${TENANT_NAME}
    ${stacknamemap}    ${service}=    Orchestrate VNF    DemoCust    ${service}   ${service}    ${TENANT_NAME}
    Save For Delete
    Close All Browsers
    Log to Console   Customer Name=${CUSTOMER_NAME}
    ${stacks}=   Get Dictionary Values    ${stacknamemap}
    :for   ${stackname}   in   @{stacks}
    \   Log to Console   VNF Module Name=${stackname}

Create Cloud If Not Exists
    [Documentation]    Creates a Cloud service in A&AI if it doesn't exist
    [Arguments]    ${AZURE_CLOUD_OWNER}    ${AZURE_CLOUD_REGION}   ${AZURE_SUBSCRIPTION_ID}    ${AZURE_CLIENT_ID}    ${AZURE_CLIENT_SECRET}    ${AZURE_TENANT_ID}
    ${result}=    Get Cloud Details    ${AZURE_CLOUD_OWNER}    ${AZURE_CLOUD_REGION}
    ${status}    ${value}=    Run Keyword And Ignore Error    Should Be Equal As Strings    ${result}    PASS
    Run Keyword If    '${status}' == 'FAIL'    Create Cloud Infrastructure in ESR    ${AZURE_CLOUD_OWNER}    ${AZURE_CLOUD_REGION}   ${AZURE_SUBSCRIPTION_ID}    ${AZURE_CLIENT_ID}    ${AZURE_CLIENT_SECRET}    ${AZURE_TENANT_ID}

Get Cloud Details
    [Documentation]    Get Cloud Details from A&AI
    [Arguments]    ${AZURE_CLOUD_OWNER}    ${AZURE_CLOUD_REGION}
	${resp}=    Run A&AI Get Request     ${AAI_INDEX_PATH}/cloud-infrastructure/cloud-regions/cloud-region/${AZURE_CLOUD_OWNER}/${AZURE_CLOUD_REGION}
    ${status}    ${value}=    Run Keyword And Ignore Error    Should Be Equal As Strings 	${resp.status_code} 	200
	[Return]  ${status}

Create Cloud Infrastructure in ESR
    [Documentation]   Create Cloud Infrastructure in ESR  using MSB
    [Arguments]    ${AZURE_CLOUD_OWNER}    ${AZURE_CLOUD_REGION}   ${AZURE_SUBSCRIPTION_ID}    ${AZURE_CLIENT_ID}    ${AZURE_CLIENT_SECRET}    ${AZURE_TENANT_ID}
    ${arguments}=    Create Dictionary    cloud_owner1=${AZURE_CLOUD_OWNER}    cloud_region_id1=${AZURE_CLOUD_REGION}    subscription_id=${AZURE_SUBSCRIPTION_ID}     client_id=${AZURE_CLIENT_ID}  secret_key=${AZURE_CLIENT_SECRET}    tenant_id1=${AZURE_TENANT_ID}
    ${data}=	Fill JSON Template File    ${CLOUD_ESR_TEMPLATE}    ${arguments}
    ${data1}    Convert JSON To String    ${data}
    ${post_resp}=    Run MSB Post Request     ${CLOUD_ESR_API}    ${data1}
    ${status_string}=    Convert To String    ${post_resp.status_code}
    Should Match Regexp    ${status_string} 	^(201|200)$


Create Tenant If Not Exists
    [Documentation]    Creates a Tenant in A&AI if it doesn't exist
    [Arguments]    ${AZURE_CLOUD_OWNER}    ${AZURE_CLOUD_REGION}   ${TENANT_ID}    ${TENANT_NAME}
    ${result}=    Get Tenant Details    ${AZURE_CLOUD_OWNER}    ${AZURE_CLOUD_REGION}    ${TENANT_ID}
    ${status}    ${value}=    Run Keyword And Ignore Error    Should Be Equal As Strings    ${result}    PASS
    Run Keyword If    '${status}' == 'FAIL'    Create Tenant Without Relationship    ${AZURE_CLOUD_OWNER}    ${AZURE_CLOUD_REGION}    ${TENANT_ID}    ${TENANT_NAME}

Get Tenant Details
    [Documentation]    Get Tenant Details from A&AI
    [Arguments]    ${AZURE_CLOUD_OWNER}    ${AZURE_CLOUD_REGION}   ${TENANT_ID}
	${resp}=    Run A&AI Get Request     ${AAI_INDEX_PATH}/cloud-infrastructure/cloud-regions/cloud-region/${AZURE_CLOUD_OWNER}/${AZURE_CLOUD_REGION}/tenants/tenant/${TENANT_ID}
    ${status}    ${value}=    Run Keyword And Ignore Error    Should Be Equal As Strings 	${resp.status_code} 	200
	[Return]  ${status}

Save For Delete
    [Documentation]   Create a variable file to be loaded for save for delete
    ${dict}=    Create Dictionary
    Set To Dictionary   ${dict}   TENANT_NAME=${TENANT_NAME}
    Set To Dictionary   ${dict}   TENANT_ID=${TENANT_ID}
    Set To Dictionary   ${dict}   CUSTOMER_NAME=${CUSTOMER_NAME}
    Set To Dictionary   ${dict}   STACK_NAME=${STACK_NAME}
    Set To Dictionary   ${dict}   SERVICE=${SERVICE}
    Set To Dictionary   ${dict}   VVG_SERVER_ID=${VVG_SERVER_ID}
    Set To Dictionary   ${dict}   SERVICE_INSTANCE_ID=${SERVICE_INSTANCE_ID}

    Set To Dictionary   ${dict}   VLB_CLOSED_LOOP_DELETE=${VLB_CLOSED_LOOP_DELETE}
    Set To Dictionary   ${dict}   VLB_CLOSED_LOOP_VNF_ID=${VLB_CLOSED_LOOP_VNF_ID}

    Set To Dictionary   ${dict}   CATALOG_SERVICE_ID=${CATALOG_SERVICE_ID}

    ${vars}=    Catenate
    ${keys}=   Get Dictionary Keys    ${dict}
    :for   ${key}   in   @{keys}
    \    ${value}=   Get From Dictionary   ${dict}   ${key}
    \    ${vars}=   Catenate   ${vars}${key} = "${value}"\n

    ${comma}=   Catenate
    ${vars}=    Catenate   ${vars}CATALOG_RESOURCE_IDS = [
    :for   ${id}   in    @{CATALOG_RESOURCE_IDS}
    \    ${vars}=    Catenate  ${vars}${comma} "${id}"
    \    ${comma}=   Catenate   ,
    ${vars}=    Catenate  ${vars}]\n
    OperatingSystem.Create File   ${FILE_CACHE}/${STACK_NAME}.py   ${vars}


