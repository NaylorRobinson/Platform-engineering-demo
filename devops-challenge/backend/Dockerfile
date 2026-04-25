# Backend container image (Node)
FROM node:18

# Work inside /app in the container
WORKDIR /app

# Copy dependency manifests first (better caching)
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the backend source code
COPY . .

# Backend listens on 8080
EXPOSE 8080

# Start the backend
CMD ["npm", "start"]