.PHONY: build

build:
	@docker build -t spark-base-hadoop:latest ./hadoop/spark-base
	@docker build -t spark-master-hadoop:latest ./hadoop/spark-master
	@docker build -t spark-worker-hadoop:latest ./hadoop/spark-worker
