from neo4j import GraphDatabase
import os
from dotenv import load_dotenv
load_dotenv()
import json
import pandas as pd
import sys

from doc_utils import *
from env_vars import *



## Delete nodes and relationships
# match (a) -[r] -> () delete a, r
# match (a) delete a

## Show whole graph (filters out nodes without relationships)
# MATCH (n)-[r]->(m) RETURN n, r, m
## Show all nodes (even ones without relatinships)
# MATCH (n)  RETURN n
## Show whole graph
# MATCH (n)
# OPTIONAL MATCH (n)-[r]->(m)
# RETURN n, r, m

## Command to run the docker file neo4j in Git Bash
# docker run --name neo4j-apoc_100 -e NEO4J_AUTH=neo4j/pleaseletmein -p 7474:7474 -p 7687:7687 -e NEO4J_apoc_export_file_enabled=true -e NEO4J_apoc_import_file_enabled=true -e NEO4J_apoc_import_file_use__neo4j__config=true -e NEO4J_PLUGINS='["apoc", "graph-data-science"]' -e NEO4J_dbms_security_procedures_unrestricted=apoc.*,algo.*,gds.* -e NEO4J_dbms_security_procedures_allowlist=apoc.*,algo.*,gds.* neo4j:5.17.0



prompt_template = """You are a helpful financial assistant, and you are designed to output JSON.
From the Financial sheet below, extract the following Entities & relationships described in the mentioned format 
0. ALWAYS FINISH THE OUTPUT. Never send partial responses
1. First, look for these Entity types in the text and generate as comma-separated format similar to entity type.
   `id` property of each entity must be alphanumeric and must be unique among the entities. You will be referring this property to define the relationship between entities. If the id is mentioned in the text, then copy it from the text, otherwise, you can generate the id. Do not create new entity types that aren't mentioned below. Document must be summarized and stored inside Project entity under `summary` property. You will have to generate as many entities as needed as per the types below:
    Entity Types:
    label:'Financial Instrument',id:string,name:string;currency:string;maturity_date:string //Financial Instrument mentioned in the brief; `id` property is the ID or code of the financial instrument, in lowercase, with no capital letters, special characters, spaces or hyphens; `name` is the name of the financial instrument, `currency` is the currency of the financial instrument, `maturity_date` is the maturity date of the financial instrument
    label:'Manufacturer',id:string,name:string //Manufacturer Entity; `id` property is the name of the manufacturer, in camel-case. If the id is mentioned in the text, then copy it from the text, otherwise, you can generate the id. `name` is the full name of the manufacturer. 
    label:'Producer',id:string,name:string;industry:string //Producer Entity; `id` property is the name of the producer, in camel-case. If the id is mentioned in the text, then copy it from the text, otherwise, you can generate the id. `name` is the full name of the producer. `industry` is the industry of the producer if it is mentioned.
    
2. Next generate each relationships as triples of head, relationship and tail. To refer the head and tail entity, use their respective `id` property. Relationship property should be mentioned within brackets as comma-separated. They should follow these relationship types below. You will have to generate as many relationships as needed as defined below:
    Relationship types:
    financial_instrument|MANUFACTURED_BY|manufacturer 
    financial_instrument|PRODUCED_BY|producer


3. The output should look like :
{{
    "entities": [{{"label":"FinancialInstrument","id":string,"name":string,"currency":string,"maturity_date":string}},{{"label":"Manufacturer","id":string,"name":string}},{{"label":"Producer","id":string,"name":string,"industry":string}}],
    "relationships": ["financial_instrument_id|MANUFACTURED_BY|manufacturer_id"]
}}

The Brief:
## START OF BRIEF
{case}
## END OF BRIEF

Output:

"""


class Neo4jManager:

    def __init__(self, 
                 uri=AZURE_NEO4J_URI, 
                 username=AZURE_NEO4J_USERNAME, 
                 password=AZURE_NEO4J_PASSWORD, 
                 database=AZURE_NEO4J_DATABASE):
        self.uri = uri
        self.username = username
        self.password = password
        self.database = database
        self.driver = GraphDatabase.driver(self.uri, auth=(self.username, self.password), encrypted=False)

        self.columns = [] 


    def close(self):
        self.driver.close()

    def financial_instrument_vec_search(self, query):
        query_vector = get_embeddings(query)  # assuming get_embeddings is implemented elsewhere

        with self.driver.session(database=self.database) as session:
            result = session.run(
                """
                MATCH (fi:FinancialInstrument)
                WITH fi.id AS fiId, fi.vector AS fiVector
                RETURN fiId, gds.similarity.cosine($vector, fiVector) AS similarity
                ORDER BY similarity DESC
                """,
                vector=query_vector
            )
            return [record for record in result]


    def node_vec_search(self, query):
        query_vector = get_embeddings(query)  # assuming get_embeddings is implemented elsewhere

        with self.driver.session(database=self.database) as session:
            result = session.run(
                """
                MATCH (n)
                WITH n.id AS nodeId, n.vector AS nodeVector
                RETURN nodeId, gds.similarity.cosine($vector, nodeVector) AS similarity
                ORDER BY similarity DESC
                """,
                vector=query_vector
            )
            return [record for record in result]


    def extract_entities_relationships(self, folder, prompt_template):
        files = []  # Adjust your file collection logic as needed
        system_msg = "You are a helpful IT-project and account management expert who extracts information from documents."
        print(f"Running pipeline for {len(files)} files in {folder} folder")
        results = []
        for i, file in enumerate(files):
            print(f"Extracting entities and relationships for {file}")
            try:
                with open(file, "r") as f:
                    text = f.read().rstrip()
                    prompt = prompt_template.format(case=text)
                    result = ask_LLM(prompt)
                    results.append(json.loads(result))
            except Exception as e:
                print(f"Error processing {file}: {e}")

        print(f"Pipeline completed in {end-start} seconds")
        return results


    def generate_cypher(self, json_obj):
        e_statements = []
        r_statements = []
        e_label_map = {}
        for i, obj in enumerate(json_obj):
            print(f"Generating cypher for file {i+1} of {len(json_obj)}")
            for entity in obj["entities"]:
                label = entity["label"]
                id = entity["id"]
                id = id.replace("-", "").replace("_", "")
                properties = {k: v for k, v in entity.items() if k not in ["label", "id"]}
                cypher = f'MERGE (n:{label} {{id: "{id}"}})'
                if properties:
                    pairs = []
                    for key, val in properties.items():
                        orig_key = key
                        if key[0].isdigit(): key = "p" + key
                        key = key.replace(" ", "_").replace("-", "_").replace("_", "_").replace("(", "").replace(")", "").replace('"', "_").replace("'", "_").replace("/", "_").replace(',', "_")
                        if isinstance(val, str): val = val.replace('"', "_").replace("'", "_")
                        # pairs.append(f'n.{key} = "{val}"')
                        pairs.append(f'{key}:"{val}"')
                        self.columns.append({"original_key":orig_key, "n_key":key})
                    props_str = ", ".join(pairs)
                    props_str +=  f', vector:{get_embeddings(id + " " + label + " " + properties["name"])}' 
                    cypher += f" ON CREATE SET n += {{ {props_str} }} ON MATCH SET n += {{ {props_str} }} "
                e_statements.append(cypher)
                e_label_map[id] = label
            for rs in obj["relationships"]:
                src_id, rs_type, tgt_id = rs.split("|")
                src_id = src_id.replace("-", "").replace("_", "")
                tgt_id = tgt_id.replace("-", "").replace("_", "")
                src_label = e_label_map[src_id]
                tgt_label = e_label_map[tgt_id]
                cypher = f'MERGE (a:{src_label} {{id: "{src_id}"}}) MERGE (b:{tgt_label} {{id: "{tgt_id}"}}) MERGE (a)-[r:{rs_type}]->(b) ON CREATE SET r.weight = 1 ON MATCH SET r.weight = r.weight + 1'
                r_statements.append(cypher)
        # with open("cyphers.txt", "w") as outfile:
        #     outfile.write("\n".join(e_statements + r_statements))
        return e_statements + r_statements


    def update_or_create_entity(self, entity_type, entity_id, properties):
        with self.driver.session(database=self.database) as session:
            # The MERGE statement here uses the label from the entity_type and matches or creates a node
            # with an 'id' property matching the provided entity_id. 
            # The properties dictionary is used to set or update additional properties.
            session.run(
                f"""
                MERGE (n:{entity_type} {{id: $entity_id}})
                ON CREATE SET n = {{id: $entity_id}} + $properties
                ON MATCH SET n += $properties
                RETURN n
                """,
                entity_id=entity_id,
                properties=properties
            )


    def execute_cypher_statements(self, cypher_statements):
        for i, stmt in enumerate(cypher_statements):
            print(f"Executing cypher statement {i+1} of {len(cypher_statements)}")
            
            try:
                self.driver.execute_query(stmt)
            except Exception as e:
                logc(f"Error executing cypher statement {i+1}: {e}")


    def delete_all_data(self):
        with self.driver.session(database=self.database) as session:
            session.run("MATCH (a)-[r]->() DELETE a, r")
            session.run("MATCH (a) DELETE a")
    


    def get_immediate_neighbors(self, node_id):
        with self.driver.session(database=self.database) as session:
            result = session.run(
                """
                MATCH (n {id: $node_id})-[r]->(m)
                RETURN n as SourceNode, properties(n) as SourceProperties, 
                       m as TargetNode, properties(m) as TargetProperties,
                       r as Relationship, properties(r) as RelationshipProperties
                ORDER BY r.weight DESC
                """,
                node_id=node_id
            )
            return [record for record in result]



    def get_node_with_properties(self, node_id):
        with self.driver.session(database=self.database) as session:
            result = session.run(
                """
                MATCH (n {id: $node_id})
                RETURN properties(n) AS Properties
                """,
                node_id=node_id
            )
            return [record for record in result]


    def get_relationship_properties(self, relationships):
        for relationship in relationships:
            # Access relationship properties
            print(f"Relationship Type: {relationship.type}")
            # Print all properties of the relationship
            for key, value in relationship.items():
                print(f"Property: {key}, Value: {value}")


    def get_all_financial_instruments(self):
        with self.driver.session(database=self.database) as session:
            result = session.run(
                """
                MATCH (fi:FinancialInstrument)
                RETURN fi.id AS id, fi.name AS name
                """
            )
            return [record for record in result]
