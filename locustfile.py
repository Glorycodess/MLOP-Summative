from locust import HttpUser, task, between
import os

class CassavaUser(HttpUser):
    wait_time = between(1, 3)

    @task
    def predict(self):
        image_path = "data/train/healthy"
        images = os.listdir(image_path)
        if images:
            image_file = os.path.join(image_path, images[0])
            with open(image_file, "rb") as f:
                self.client.post(
                    "/predict",
                    files={"file": (images[0], f, "image/jpeg")}
                )

    @task
    def health_check(self):
        self.client.get("/health")
