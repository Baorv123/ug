// ==UserScript==
// @name         Auto Mua Máy Ugphone 4H - Gia Bảo
// @namespace    https://ugphone.com/
// @version      3.0
// @description  Mua máy 4H tự động, đăng nhập, đăng xuất, chọn server
// @author       Gia Bảo
// @match        https://www.ugphone.com/toc-portal/*
// @icon         https://cdn-icons-png.flaticon.com/512/1995/1995485.png
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  // ===== CONFIG =====
  const CONFIG = {
    gifBg: 'https://i.pinimg.com/originals/3b/9a/1e/3b9a1ec7b868b4b107bce28f783fb566.gif',
    icon: 'https://cdn-icons-png.flaticon.com/512/1995/1995485.png',
    menuTitle: 'Auto Ugphone',
    servers: ['Singapore', 'HongKong'],
  };

  // ===== HTML UI =====
  const box = document.createElement('div');
  box.innerHTML = `
  <div id="ug-ext-btn" style="position:fixed;top:20px;right:20px;width:50px;height:50px;border-radius:50%;background:#4a6bdf url('${CONFIG.icon}') center/60% no-repeat;cursor:pointer;z-index:99999;border:2px solid white;"></div>
  <div id="ug-ext-panel" style="display:none;position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);background:#fff;border-radius:16px;padding:20px;z-index:99998;width:360px;box-shadow:0 8px 32px rgba(0,0,0,0.2);overflow:hidden;">
    <img src="${CONFIG.gifBg}" style="position:absolute;top:0;left:0;width:100%;height:100%;object-fit:cover;opacity:0.15;z-index:1;pointer-events:none">
    <div style="position:relative;z-index:2">
      <h2 style="margin:0 0 12px;color:#333;text-align:center">${CONFIG.menuTitle}</h2>
      <textarea id="ug-json" placeholder="Paste localStorage JSON..." style="width:100%;height:100px;padding:10px;margin-bottom:10px;border-radius:8px;border:1px solid #ccc"></textarea>
      <select id="ug-server" style="width:100%;padding:8px;border-radius:8px;margin-bottom:10px">
        ${CONFIG.servers.map(s => `<option value="${s.toLowerCase()}">${s}</option>`).join('')}
      </select>
      <button id="ug-login" style="width:100%;padding:10px;margin-bottom:8px;border-radius:8px;background:#4a6bdf;color:white;border:none">Đăng nhập</button>
      <button id="ug-logout" style="width:100%;padding:10px;margin-bottom:8px;border-radius:8px;background:#e74c3c;color:white;border:none">Đăng xuất</button>
      <button id="ug-buy" style="width:100%;padding:10px;border-radius:8px;background:#f39c12;color:white;border:none">Mua Máy Ugphone 4H</button>
      <p id="ug-msg" style="text-align:center;color:#c0392b;margin-top:10px;font-weight:bold"></p>
    </div>
  </div>`;
  document.body.appendChild(box);

  const $ = id => document.getElementById(id);
  $('ug-ext-btn').onclick = () => $('ug-ext-panel').style.display = 'block';

  $('ug-login').onclick = () => {
    try {
      const data = JSON.parse($('ug-json').value);
      for (const [k, v] of Object.entries(data))
        localStorage.setItem(k, typeof v === 'object' ? JSON.stringify(v) : v);
      $('ug-msg').textContent = '✅ Đăng nhập thành công!';
      setTimeout(() => location.reload(), 1000);
    } catch {
      $('ug-msg').textContent = '❌ JSON không hợp lệ!';
    }
  };

  $('ug-logout').onclick = () => {
    localStorage.clear();
    $('ug-msg').textContent = '✅ Đã đăng xuất';
    setTimeout(() => location.reload(), 1000);
  };

  $('ug-buy').onclick = async () => {
    try {
      const mqtt = JSON.parse(localStorage.getItem('UGPHONE-MQTT') || '{}');
      const token = mqtt.access_token;
      const loginId = mqtt.login_id;
      if (!token || !loginId) throw 'Chưa đăng nhập hoặc thiếu token';
      const headers = {
        'access-token': token,
        'login-id': loginId,
        'content-type': 'application/json',
        'lang': 'vi',
        'terminal': 'web'
      };

      // Lấy config_id
      const r1 = await fetch('https://www.ugphone.com/api/apiv1/info/configList2', { headers });
      const j1 = await r1.json();
      const configId = j1.data?.list?.[0]?.android_version?.[0]?.config_id;
      if (!configId) throw 'Không lấy được config_id';

      // Lấy subscription (gói)
      const r2 = await fetch('https://www.ugphone.com/api/apiv1/info/mealList', {
        method: 'POST', headers,
        body: JSON.stringify({ config_id: configId })
      });
      const j2 = await r2.json();
      const subs = j2.data?.list?.[0]?.subscription || [];

      // Mua thử từng network_id
      for (const sub of subs) {
        const netId = sub.network_id;
        const priceRes = await fetch('https://www.ugphone.com/api/apiv1/fee/queryResourcePrice', {
          method: 'POST', headers,
          body: JSON.stringify({
            order_type: 'newpay', unit: 'hour', period_time: '4',
            resource_type: 'cloudphone',
            resource_param: {
              pay_mode: 'subscription', config_id: configId,
              network_id: netId, count: 1, use_points: 3, points: 250
            }
          })
        });
        const priceJson = await priceRes.json();
        const amountId = priceJson.data?.amount_id;
        if (!amountId) continue;

        // Gửi yêu cầu thanh toán
        const payRes = await fetch('https://www.ugphone.com/api/apiv1/fee/payment', {
          method: 'POST', headers,
          body: JSON.stringify({ amount_id: amountId, pay_channel: 'free' })
        });
        const payJson = await payRes.json();
        if (payJson.code === 200) {
          $('ug-msg').textContent = `✅ Đã mua máy thành công tại server ${$('ug-server').value.toUpperCase()}`;
          setTimeout(() => location.reload(), 1500);
          return;
        }
      }
      throw '❌ Không thể mua máy lúc này';
    } catch (err) {
      $('ug-msg').textContent = typeof err === 'string' ? err : '❌ Lỗi khi mua máy';
    }
  };
})();
