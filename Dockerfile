FROM node:18.15.0  AS base
RUN echo "base"

# BASE IMAGE
FROM base AS builder
RUN echo "builder"

# Set working directory
WORKDIR /usr/app

# Copy project files
COPY package.json ./
COPY pnpm-lock.yaml ./# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
# Omit --production flag for TypeScript devDependencies
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i; \
  # Allow install without lockfile, so example works even without Node.js installed locally
  else echo "Warning: Lockfile not found. It is recommended to commit lockfiles to version control." && yarn install; \
  fi
COPY tsconfig*.json ./

# Install pnpm package manager and project dependencies
RUN npm install -g pnpm
RUN pnpm install

# Copy project files and build
COPY . .

RUN npx prisma generate

RUN pnpm nx run main:build:production

## Copy project files and dependencies from base image
#
## Expose the port for the application
#EXPOSE 3000
#
##USER node
#
## Start the application with the custom command
##CMD [ "pm2-runtime", "start", "npm", "--", "serve:main:prod" ]
#CMD ["npm", "run", "nx", "run", "main:serve:production"]

# BASE IMAGE
FROM base AS runner
ARG APP=main
RUN echo "runner"

ENV NODE_ENV=production

# Don't run production as root
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

USER nextjs

## Set working directory
WORKDIR /usr/app

COPY --from=builder --chown=nextjs:nodejs /usr/app/apps/${APP}/public/ ./apps/${APP}/public/

COPY --from=builder --chown=nextjs:nodejs /usr/app/dist/apps/${APP}/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /usr/app/dist/apps/${APP}/.next/static ./dist/apps/${APP}/.next/static

# Uncomment the following line to disable telemetry at run time
# ENV NEXT_TELEMETRY_DISABLED 1

# Note: Don't expose ports here, Compose will handle that for us

CMD ["node", "apps/main/server.js"]
