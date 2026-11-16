module EncryptedSecret
  # 用应用密钥加密并签名敏感字符串，解密时校验签名。
  def self.encrypt(value : String) : String
    encryptor.encrypt_and_sign(value)
  end

  def self.decrypt(encrypted_value : String) : String
    String.new(encryptor.verify_and_decrypt(encrypted_value))
  end

  private def self.encryptor : Lucky::MessageEncryptor
    Lucky::MessageEncryptor.new(
      secret: Lucky::Server.settings.secret_key_base,
      digest: :sha256
    )
  end
end
