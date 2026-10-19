from insightface.app import FaceAnalysis

class FaceEngine:
    def __init__(self, model_name: str, det_size: int):
        self.app = FaceAnalysis(name=model_name, providers=["CPUExecutionProvider"])
        self.app.prepare(ctx_id=-1, det_size=(det_size, det_size))

    def analyze(self, bgr_image):
        return self.app.get(bgr_image)

# Variabel global untuk menyimpan AI di memori
face_app_instance = None