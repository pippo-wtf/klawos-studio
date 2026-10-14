class Unlocker:
    @staticmethod
    def unlock(keyboard): raise PermissionError('Explicit physical unlock is required; never unlock during readback')
