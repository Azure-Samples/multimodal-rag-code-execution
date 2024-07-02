import json
import logging

from azureml.core import Workspace, Experiment, Environment, ScriptRunConfig, Datastore
from azureml.core.compute import ComputeTarget, AmlCompute
from azureml.core.compute_target import ComputeTargetException
from azureml.exceptions import UserErrorException
from azureml.core.authentication import ServicePrincipalAuthentication

from env_vars import *

## AML Cheat Sheet
# https://azure.github.io/azureml-cheatsheets/docs/cheatsheets/python/v1/cheatsheet

class AmlJob():

    def __init__(self,
                subscription_id=AML_SUBSCRIPTION_ID,
                resource_group=AML_RESOURCE_GROUP,
                workspace_name=AML_WORKSPACE_NAME,
                account_name = AZURE_FILE_SHARE_ACCOUNT,
                file_share_name = AZURE_FILE_SHARE_NAME ,
                account_key = AZURE_FILE_SHARE_KEY,
        ):

        self.cpu_cluster_name = AML_CLUSTER_NAME
        self.file_share_datastore_name='research_copilot_datastore'
        self.experiments_name = 'research_copilot_experiments'
        self.env_name = 'research_copilot_env'

        self.account_name = account_name
        self.file_share_name = file_share_name 
        self.account_key = account_key
        self.subscription_id = subscription_id
        self.resource_group = resource_group
        self.workspace_name = workspace_name
                
        svc_pr = ServicePrincipalAuthentication(
            tenant_id=AML_TENANT_ID,
            service_principal_id=AML_SERVICE_PRINCIPAL_ID,
            service_principal_password=AML_PASSWORD)

        try:
            logging.info(f'Accessing workspace {workspace_name} using environment variables.')
            self.ws = Workspace(
                    subscription_id=subscription_id,
                    resource_group=resource_group,
                    workspace_name=workspace_name,
                    auth=svc_pr
                )            
        except Exception as e:
            logging.error(f"Could not access AML Workspace: {str(e)}")
            try:
                self.ws = Workspace.from_config()
                logging.warn(f'Accessing workspace using config.json')
                
            except Exception as e:
                logging.critical(f"Could not create AML Workspace: {str(e)}")

        self.cpu_cluster = None
        self.env = None
        self.file_share_datastore = None

    def create_or_get_file_share_datastore(self):
        try:
            self.file_share_datastore = Datastore.get(self.ws, self.file_share_datastore_name)
            logging.info("Found File Share Datastore with name: %s" % self.file_share_datastore_name)
        except UserErrorException:
            self.file_share_datastore = Datastore.register_azure_file_share(
                workspace=self.ws,
                datastore_name=self.file_share_datastore_name,
                account_name=self.account_name, # Storage account name
                file_share_name=self.file_share_name, # Name of Azure blob container
                account_key=self.account_key) # Storage account key
            logging.info("Registered file share datastore with name: %s" % self.file_share_datastore_name)

    def create_or_get_environment(self):
        try:
            self.env = self.ws.environments[self.env_name]
            logging.info(f'Found existing environment {self.env_name}, use it.')
        except:
            env = Environment.from_pip_requirements(self.env_name, 'requirements.txt')
            env.register(self.ws)
            self.env = self.ws.environments[self.env_name]
            logging.info(f'Creating new environment {self.env_name}.')

    def create_environment_variables_string(self):
        env_vars = []

        for k, v in os.environ.items():
            azure_ev = False
            for prefix in ['AZURE', 'APPLICATIONINSIGHTS', 'COG', 'COSMOS', 'TEXT_CHUNK', 'DI_', 'PYTHONPATH', 'AML', 'OPENAI', 'ROOT_PATH_INGESTION', 'BLOB']:
                if prefix in k:
                    azure_ev = True

            if azure_ev: 
                env_vars.append(f"{k}='{v}'".replace('\\', '/'))
                self.env.environment_variables[k] = v

        logging.info(f"Created an environment string with {len(env_vars)} variables.")

        return env_vars

    def create_or_get_compute(self):
        # Verify that the cluster does not exist already
        try:
            self.cpu_cluster = ComputeTarget(workspace=self.ws, name=self.cpu_cluster_name)
            logging.info(f'Found existing cluster {self.cpu_cluster_name}, use it')

        except ComputeTargetException:
            compute_config = AmlCompute.provisioning_configuration(vm_size=AML_VMSIZE, max_nodes=3, idle_seconds_before_scaledown=2400)
            self.cpu_cluster = ComputeTarget.create(self.ws, self.cpu_cluster_name, compute_config)
            self.cpu_cluster.wait_for_completion(show_output=True)
            logging.warn(f'Creating new cluster {self.cpu_cluster_name}.')

    def submit_ingestion_job(self, ingestion_params_dict, script = 'ingest_doc.py', source_directory='./code'):
        if self.cpu_cluster is None: self.create_or_get_compute()
        if self.env is None: self.create_or_get_environment()
        if self.file_share_datastore is None: self.create_or_get_file_share_datastore()

        self.exp = Experiment(self.ws, self.experiments_name)

        data_ref = self.file_share_datastore.path('data').as_mount()
        data_ref.path_on_compute = '/mnt/data'

        ingestion_params_dict['datastore'] = self.file_share_datastore_name
        ingestion_params_dict['datastore_mount'] = str(data_ref)

        # Check if source_directory exists, if not, use '../code or .'
        if not os.path.isdir(source_directory):
            source_directory = '../code'
        if not os.path.isdir(source_directory):
            source_directory = '.'

        command_string = 'export MSYS_NO_PATHCONV=1 ' + \
                         ' '.join(self.create_environment_variables_string()) + \
                         f" && python {script} --ingestion_params_dict '{json.dumps(ingestion_params_dict)}'"     
        logging.info(f'Source directory for AML: ${source_directory}')
        self.config = ScriptRunConfig(
            source_directory=source_directory,
            command=command_string,
            compute_target=self.cpu_cluster,
            environment=self.env,
        )

        self.config.run_config.data_references[data_ref.data_reference_name] = data_ref.to_config()

        run = self.exp.submit(self.config)
        logging.info(run)
        return run.id

    def check_job_status_using_run_id(self, run_id):
        run = self.ws.get_run(run_id)
        status = run.get_status()
        logging.info(f"AML Run status: {status}")

        return status
