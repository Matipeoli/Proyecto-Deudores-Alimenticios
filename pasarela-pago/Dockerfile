FROM node:20-alpine 
WORKDIR /app 
COPY pluspagos-mock-simple/ . 
RUN npm install 
COPY . . 
EXPOSE 4000 
CMD ["node", "server.js"]
