(() => {
  let scriptPromise;

  function ensureScriptLoaded() {
    if (typeof window.initGeetest4 === 'function') {
      return Promise.resolve();
    }
    if (scriptPromise) {
      return scriptPromise;
    }
    scriptPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://static.geetest.com/v4/gt4.js';
      script.async = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error('验证码脚本加载失败'));
      document.head.appendChild(script);
    });
    return scriptPromise;
  }

  window.interKnotVerifyCaptcha = function (captchaId) {
    return ensureScriptLoaded().then(
      () =>
        new Promise((resolve, reject) => {
          if (typeof window.initGeetest4 !== 'function') {
            reject(new Error('验证码脚本未加载完成'));
            return;
          }

          let settled = false;

          window.initGeetest4(
            {
              captchaId,
              product: 'bind',
              language: 'zho',
            },
            function (captchaObj) {
              const cleanup = () => {
                try {
                  captchaObj.destroy();
                } catch (_) {}
              };

              captchaObj.onSuccess(function () {
                if (settled) return;
                settled = true;
                const result = captchaObj.getValidate();
                cleanup();
                if (result) {
                  resolve(result);
                  return;
                }
                reject(new Error('验证码结果无效'));
              });

              captchaObj.onError(function (error) {
                if (settled) return;
                settled = true;
                cleanup();
                reject(new Error(error && error.msg ? error.msg : '验证码校验失败'));
              });

              captchaObj.onClose(function () {
                if (settled) return;
                settled = true;
                cleanup();
                reject(new Error('CAPTCHA_CANCELLED'));
              });

              captchaObj.onReady(function () {
                try {
                  captchaObj.showCaptcha();
                } catch (error) {
                  if (settled) return;
                  settled = true;
                  cleanup();
                  reject(error instanceof Error ? error : new Error('验证码拉起失败'));
                }
              });
            },
          );
        }),
    );
  };
})();
