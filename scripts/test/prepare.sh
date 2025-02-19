#!/bin/bash
# Copyright 2020 The SQLFlow Authors. All rights reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

mkdir -p build

# 1. install python deps
python -m pip install sqlflow_models
python -m pip install "numpy>=1.16.2,<1.19.0" \
    "tensorflow-metadata>=0.22.2" \
    "tensorflow==2.2.3" \
    "impyla==0.16.0" \
    "pyodps==0.8.3" \
    "dill==0.3.0" \
    "shap==0.30.1" \
    "xgboost==0.90" \
    "oss2==2.9.0" \
    "plotille==3.7" \
    "seaborn==0.9.0" \
    "scikit-learn>=0.21.3" \
    "sklearn2pmml==0.56.0" \
    "jpmml-evaluator==0.3.1" \
    "PyUtilib==5.8.0" \
    "pyomo==5.6.9" \
    "mysqlclient==1.4.4" \
    "grpcio-tools==1.28.1" \
    "googleapis-common-protos==1.52.0" \
    pytest \
    pytest-cov

sudo apt-get update
sudo apt-get install -y git

git clone https://github.com/couler-proj/couler.git
(cd couler && git fetch origin && \
git checkout 9c93f72791ebf5411fc5bec7d68890de753d8431  && \
python setup.py install)

protoc --python_out=python/runtime/dbapi/table_writer/ -I go/proto sqlflow.proto
python -m grpc_tools.protoc --python_out=python/runtime/model/ --grpc_python_out=python/runtime/model/ -I go/proto modelzooserver.proto

# A workaround for the issue: https://github.com/protocolbuffers/protobuf/issues/1491
sed -i 's/import modelzooserver_pb2/from . import modelzooserver_pb2/g' python/runtime/model/modelzooserver_pb2_grpc.py

# 3. install java parser
echo "Build parser gRPC servers in Java ..."

# clean up previous build
rm -rf "$SQLFLOW_PARSER_SERVER_LOADING_PATH"
mkdir -p "$SQLFLOW_PARSER_SERVER_LOADING_PATH"

# Make mvn compile quiet
export MAVEN_OPTS="-Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn"

(cd java/parse-interface && \
mvn -B -q clean install)

(cd java/parser-hive && \
mvn -B -q clean compile assembly:single && \
mv target/*.jar "$SQLFLOW_PARSER_SERVER_LOADING_PATH" )

(cd java/parser-calcite && \
mvn -B -q clean compile assembly:single && \
mv target/*.jar "$SQLFLOW_PARSER_SERVER_LOADING_PATH" )

(cd java/parser && \
protoc --java_out=src/main/java \
       --grpc-java_out=src/main/java/ \
       --proto_path=src/main/proto/ \
       src/main/proto/parser.proto && \
mvn -B -q clean compile assembly:single && \
cp target/*.jar "$SQLFLOW_PARSER_SERVER_LOADING_PATH" )

# Go deps:
go install golang.org/x/tools/cmd/goyacc@latest
go install github.com/golang/protobuf/protoc-gen-go@v1.3.3
go install github.com/wangkuiyi/ipynb/markdown-to-ipynb@latest
