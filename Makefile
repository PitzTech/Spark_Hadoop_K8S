.PHONY: build download

download:
	@echo "Downloading required dependencies..."
	@mkdir -p hadoop/spark-base/bin
	@if [ ! -f hadoop/spark-base/bin/hadoop-3.4.0.tar.gz ]; then \
		echo "Downloading Hadoop 3.4.0..."; \
		curl -L "https://drive.google.com/uc?id=1LCQEl0pVk3mCjbZZ4sZtXTG3fD68w7Oy&export=download" -o hadoop/spark-base/bin/hadoop-3.4.0.tar.gz; \
	else \
		echo "Hadoop 3.4.0 already exists"; \
	fi
	@if [ ! -f hadoop/spark-base/bin/spark-3.5.0-bin-hadoop3.tgz ]; then \
		echo "Downloading Spark 3.5.0..."; \
		curl -L "https://drive.google.com/uc?id=19MRDBRugUU6mjB_cEhRhZBOJy92Z8gve&export=download" -o hadoop/spark-base/bin/spark-3.5.0-bin-hadoop3.tgz; \
	else \
		echo "Spark 3.5.0 already exists"; \
	fi
	@echo "Dependencies downloaded successfully!"

build: download
	@echo "Building Docker images..."
	@docker build -t spark-base-hadoop:latest ./hadoop/spark-base
	@docker build -t spark-master-hadoop:latest ./hadoop/spark-master
	@docker build -t spark-worker-hadoop:latest ./hadoop/spark-worker
	@echo "Docker images built successfully!"
