# Use Node image
FROM node:16

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy app source
COPY . .

# Build production static files
RUN npm run build

# Install simple static server
RUN npm install -g serve

# Expose port 3000
EXPOSE 3000

# Serve production build
CMD ["serve", "-s", "build", "-l", "3000"]