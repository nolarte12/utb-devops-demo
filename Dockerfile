FROM amazoncorretto:21

WORKDIR /app/utb-devops-demo

COPY ./build/libs/demo-0.0.1-SNAPSHOT.jar .

EXPOSE 8080

CMD ["java", "-jar", "demo-0.0.1-SNAPSHOT.jar"]
