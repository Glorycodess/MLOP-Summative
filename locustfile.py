from locust import HttpUser, task, between

class CassavaUser(HttpUser):
    wait_time = between(1, 2)

    @task
    def health_check(self):
        self.client.get("/health")

    @task
    def metrics_check(self):
        self.client.get("/metrics")