FROM eclipse-temurin:25-jdk-alpine
# Set the working directory inside the container
WORKDIR /app

# Copy the compiled .jar file into the container
COPY target/smart-apt-monitor-0.0.1-SNAPSHOT.jar app.jar

# Expose the API port
EXPOSE 8080

# Run the Spring Boot app
ENTRYPOINT ["java", "-jar", "app.jar"]