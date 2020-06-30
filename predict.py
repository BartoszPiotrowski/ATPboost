

def predict(models, conjs):
    preds = []
    for model in models:
        preds.append(model.predict(conjs))
    return preds


