Spec.before_each do
  CAPTCHA_LOCK.synchronize do
    CAPTCHA_CACHE.clear
  end
end
