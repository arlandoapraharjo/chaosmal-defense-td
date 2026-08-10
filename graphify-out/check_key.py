import os
print('KEY_SET:', bool(os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')))
