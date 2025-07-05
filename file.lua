// ==UserScript==
// @name         UGPHONE Auto Gia Bảo
// @namespace    https://ugphone.com/
// @version      1.0
// @description  Tự đăng nhập, mua máy 4H, chọn server UgPhone
// @author       Gia Bảo
// @match        https://www.ugphone.com/*
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  const CONFIG = {
    backgroundImage: 'https://image.tmdb.org/t/p/original/bn5tRLVQjaxAgq6nxs4Rv6cd1xv.jpg',
    autoBuyText: 'Mua máy 4H',
    loginText: 'Nhập localStorage',
    logoutText: 'Xóa localStorage',
    servers: [
      { name: 'HongKong', id: 'hk' },
      { name: 'Singapore', id: 'sg' }
    ]
  };

  const html = `
    <div id="ug-auto-ui" style="position:fixed;top:100px;right:20px;z-index:99999;width:360px;background:#fff;border-radius:16px;box-shadow:0 4px 20px rgba(0,0,0,0.2);overflow:hidden;font-family:sans-serif">
      <div style="background:url('${CONFIG.backgroundImage}') no-repeat center/cover;height:160px;"></div>
      <div style="padding:16px">
        <textarea id="ug-json" placeholder="Dán localStorage JSON..." style="width:100%;height:100px;padding:10px;border-radius:8px;border:1px solid #ccc;resize:none;font-family:monospace"></textarea>
        <div style="display:flex;gap:8px;margin-top:10px">
          <button id="ug-login" style="flex:1;padding:8px;border:none;background:#2980b9;color:white;border-radius:6px">${CONFIG.loginText}</button>
          <button id="ug-logout" style="flex:1;padding:8px;border:none;background:#c0392b;color:white;border-radius:6px">${CONFIG.logoutText}</button>
        </div>
        <select id="ug-server" style="margin-top:12px;width:100%;padding:8px;border-radius:6px">
          ${CONFIG.servers.map(s => `<option value="${s.id}">${s.name}</option>`).join('')}
        </select>
        <button id="ug-buy" style="margin-top:12px;width:100%;padding:10px;background:#27ae60;color:white;border:none;border-radius:6px;font-weight:bold">${CONFIG.autoBuyText}</button>
      </div>
    </div>
  `;

  document.body.insertAdjacentHTML('beforeend', html);

  const $ = id => document.getElementById(id);

  $('ug-login').onclick = () => {
    try {
      const data = JSON.parse($('ug-json').value);
      for (const [k, v] of Object.entries(data))
        localStorage.setItem(k, typeof v === 'object' ? JSON.stringify(v) : String(v));
      alert('Đã đăng nhập! Reload lại trang.');
    } catch (e) {
      alert('JSON không hợp lệ!');
    }
  };

  $('ug-logout').onclick = () => {
    localStorage.clear();
    alert('Đã xoá localStorage. Reload trang.');
  };

  $('ug-buy').onclick = async () => {
    const mqtt = JSON.parse(localStorage.getItem('UGPHONE-MQTT') || '{}');
    const headers = {
      'accept': 'application/json, text/plain, */*',
      'content-type': 'application/json;charset=UTF-8',
      'access-token': mqtt.access_token,
      'login-id': mqtt.login_id
    };
    try {
      await fetch('https://www.ugphone.com/api/apiv1/fee/newPackage', {
        method: 'POST',
        headers
      });
      const json1 = await fetch('https://www.ugphone.com/api/apiv1/info/configList2', { headers }).then(r => r.json());
      const config_id = json1.data?.list?.[0]?.android_version?.[0]?.config_id;
      if (!config_id) throw new Error('Không lấy được config_id');
      const json2 = await fetch('https://www.ugphone.com/api/apiv1/info/mealList', {
        method: 'POST',
        headers,
        body: JSON.stringify({ config_id })
      }).then(r => r.json());
      const netList = json2.data?.list?.flatMap(i => i.subscription || []) || [];
      for (const sub of netList) {
        const net_id = sub.network_id;
        const priceRes = await fetch('https://www.ugphone.com/api/apiv1/fee/queryResourcePrice', {
          method: 'POST',
          headers,
          body: JSON.stringify({
            order_type: 'newpay', period_time: '4', unit: 'hour',
            resource_type: 'cloudphone',
            resource_param: { pay_mode: 'subscription', config_id, network_id: net_id, count: 1, use_points: 3, points: 250 }
          })
        }).then(r => r.json());
        const amount_id = priceRes.data?.amount_id;
        if (!amount_id) continue;
        const payRes = await fetch('https://www.ugphone.com/api/apiv1/fee/payment', {
          method: 'POST',
          headers,
          body: JSON.stringify({ amount_id, pay_channel: 'free' })
        }).then(r => r.json());
        if (payRes.code === 200) {
          alert('Đã mua máy thành công!');
          location.reload();
          break;
        }
      }
    } catch (e) {
      alert('Lỗi khi mua máy: ' + e.message);
    }
  };
})();
