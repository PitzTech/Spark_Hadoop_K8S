.PHONY: build

build:
	@docker build -t raulcsouza/spark-base-hadoop ./hadoop/spark-base
	@docker build -t raulcsouza/spark-master-hadoop ./hadoop/spark-master
	@docker build -t raulcsouza/spark-worker-hadoop ./hadoop/spark-worker
