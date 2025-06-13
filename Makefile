.PHONY: build download clean test-network

test-network:
	@echo "Testing network connectivity..."
	@docker run --rm --dns=8.8.8.8 --dns=8.8.4.4 ubuntu:20.04 /bin/bash -c "apt-get update -qq && echo 'Network test successful!'"

download:
	@echo "Downloading required dependencies..."
	@mkdir -p hadoop/spark-base/bin
	@if [ ! -f hadoop/spark-base/bin/hadoop-3.4.0.tar.gz ]; then \
		echo "Downloading Hadoop 3.4.0..."; \
		gdown "https://drive.google.com/uc?id=1LCQEl0pVk3mCjbZZ4sZtXTG3fD68w7Oy" -O hadoop/spark-base/bin/hadoop-3.4.0.tar.gz; \
	else \
		echo "Hadoop 3.4.0 already exists"; \
	fi; \
	if [ ! -f hadoop/spark-base/bin/hadoop-3.4.0.tar.gz ]; then \
		echo "ERROR: Hadoop 3.4.0 download failed! Please download manually:"; \
		echo "https://drive.google.com/uc?id=1LCQEl0pVk3mCjbZZ4sZtXTG3fD68w7Oy"; \
		exit 1; \
	fi
	@if [ ! -f hadoop/spark-base/bin/spark-3.5.0-bin-hadoop3.tgz ]; then \
		echo "Downloading Spark 3.5.0..."; \
		gdown "https://drive.google.com/uc?id=19MRDBRugUU6mjB_cEhRhZBOJy92Z8gve" -O hadoop/spark-base/bin/spark-3.5.0-bin-hadoop3.tgz; \
	else \
		echo "Spark 3.5.0 already exists"; \
	fi; \
	if [ ! -f hadoop/spark-base/bin/spark-3.5.0-bin-hadoop3.tgz ]; then \
		echo "ERROR: Spark 3.5.0 download failed! Please download manually:"; \
		echo "https://drive.google.com/uc?id=19MRDBRugUU6mjB_cEhRhZBOJy92Z8gve"; \
		exit 1; \
	fi
	@echo "Dependencies downloaded successfully!"

build: download
	@echo "Building Docker images..."
	@echo "Building with host network mode..."
	@sudo docker build -t spark-base-hadoop:latest ./hadoop/spark-base
	@sudo docker build -t spark-master-hadoop:latest ./hadoop/spark-master
	@sudo docker build -t spark-worker-hadoop:latest ./hadoop/spark-worker
	@echo "Docker images built successfully!"

clean:
	@echo "Cleaning up Docker images and containers..."
	@sudo docker system prune -f
	@sudo docker rmi spark-base-hadoop:latest spark-master-hadoop:latest spark-worker-hadoop:latest 2>/dev/null || true

# Alternative build with Ubuntu base (if Debian continues to fail)
build-ubuntu: download
	@echo "Building with Ubuntu base image..."
	@DOCKER_BUILDKIT=0 docker build \
		--no-cache \
		--network=host \
		--dns=8.8.8.8 \
		--dns=8.8.4.4 \
		--build-arg BASE_IMAGE=ubuntu:20.04 \
		-t spark-base-hadoop:latest \
		-f ./hadoop/spark-base/Dockerfile.ubuntu \
		./hadoop/spark-base
