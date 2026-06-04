FROM docker.m.daocloud.io/library/maven:3.9-eclipse-temurin-17-alpine AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B -q || true
COPY src ./src
RUN mvn package -DskipTests -B -q

FROM docker.m.daocloud.io/library/eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
