# Base image
FROM python:3.11-slim

# Environment
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

# Create app user
RUN useradd -m appuser

# Set workdir
WORKDIR /app

# Install dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy all app source, templates, and static folders
COPY . .

# Set permissions and switch to non-root
RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8081

# Start Flask
CMD ["python", "app1.py"]
