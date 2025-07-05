// ==UserScript==
// @name         Auto UGPHONE Gia Bảo
// @namespace    https://ugphone.com/
// @version      1.0
// @description  Auto mua máy UGPhone theo server (Sing/HongKong), login/logout qua LocalStorage, UI mini có gif nền.
// @author       Gia Bảo
// @match        https://www.ugphone.com/toc-portal/#/dashboard/*
// @grant        none
// ==/UserScript==

(function () {
  'use strict';

  // ===== CONFIG =====
  const gifURL = 'https://i.pinimg.com/originals/3b/9a/1e/3b9a1ec7b868b4b107bce28f783fb566.gif';
  const networkMap = {
    'singapore': '3731f6bf-b812-e983-782b-152cdab81276',
    'hongkong': '3731f6bf-b812-e983-872b-125cdab81276'
  };
  let selectedServer = 'singapore'; // default

  // ===== CREATE UI =====
  const ui = document.createElement('div');
  ui.innerHTML = `
    <div id="ugbox" style="position:fixed;top:80px;left:20px;z-index:9999;background:#fff;border-radius:12px;padding:10px;box-shadow:0 0 10px rgba(0,0,0,0.3);width:300px;cursor:move">
      <div style="text-align:center;margin-bottom:5px">
        <img src="https://i.pinimg.com/736x/d9/2f/32/d92f3267b029a642788b0cd929be7c2e.jpg" style="height:50px;border-radius:8px">
      </div>
      <div style="margin-bottom:5px">
        <select id="serverSelect" style="width:100%;padding:4px;border-radius:6px">
          <option value="singapore">Server Singapore</option>
          <option value="hongkong">Server HongKong</option>
        </select>
      </div>
      <textarea id="localInput" placeholder='Dán LocalStorage JSON vào đây' style='width:100%;height:80px'></textarea>
      <button id="loginBtn" style="width:100%;margin:4px 0;background:#3498db;color:white;border:none;padding:8px;border-radius:6px">Login</button>
      <button id="logoutBtn" style="width:100%;margin:4px 0;background:#e74c3c;color:white;border:none;padding:8px;border-radius:6px">Logout</button>
      <button id="buyBtn" style="width:100%;margin:4px 0;background:#2ecc71;color:white;border:none;padding:8px;border-radius:6px">Mua Máy 4H</button>
      <div id="ugstatus" style='margin-top:6px;font-size:13px;color:#555;text-align:center'>UGPHONE Tool by Gia Bảo</div>
    </div>
    <img src="${gifURL}" style="position:fixed;bottom:10px;right:10px;width:150px;border-radius:12px;z-index:9999;pointer-events:none">
  `;
  document.body.appendChild(ui);

  // ===== DRAG =====
  const ugbox = document.getElementById('ugbox');
  ugbox.onmousedown = function (e) {
    e.preventDefault();
    let shiftX = e.clientX - ugbox.getBoundingClientRect().left;
    let shiftY = e.clientY - ugbox.getBoundingClientRect().top;
    function moveAt(pageX, pageY) {
      ugbox.style.left = pageX - shiftX + 'px';
      ugbox.style.top = pageY - shiftY + 'px';
    }
    function onMouseMove(e) {
      moveAt(e.pageX, e.pageY);
    }
    document.addEventListener('mousemove', onMouseMove);
    ugbox.onmouseup = function () {
      document.removeEventListener('mousemove', onMouseMove);
      ugbox.onmouseup = null;
    };
  };

  // ===== BUTTON EVENTS =====
  document.getElementById('serverSelect').onchange = e => selectedServer = e.target.value;

  document.getElementById('loginBtn').onclick = () => {
    try {
      const json = JSON.parse(document.getElementById('localInput').value);
      for (let k in json) localStorage.setItem(k, json[k]);
      location.reload();
    } catch (e) {
      document.getElementById('ugstatus').textContent = '❌ JSON không hợp lệ';
    }
  };

  document.getElementById('logoutBtn').onclick = () => {
    localStorage.clear();
    location.reload();
  };

  document.getElementById('buyBtn').onclick = async () => {
    const token = JSON.parse(localStorage.getItem('UGPHONE-MQTT') || '{}').access_token;
    const loginId = JSON.parse(localStorage.getItem('UGPHONE-MQTT') || '{}').login_id;
    if (!token || !loginId) return alert('Vui lòng đăng nhập trước!');
    const network_id = networkMap[selectedServer];
    const headers = {
      'access-token': token,
      'login-id': loginId,
      'content-type': 'application/json;charset=UTF-8'
    };

    const fetchJson = (url, data = {}) => fetch(url, {
      method: 'POST', headers, body: JSON.stringify(data)
    }).then(r => r.json());

    try {
      const configRes = await fetchJson('https://www.ugphone.com/api/apiv1/info/configList2');
      const config_id = configRes?.data?.list?.[0]?.android_version?.[0]?.config_id;
      if (!config_id) throw 'Không lấy được config_id';
      const priceRes = await fetchJson('https://www.ugphone.com/api/apiv1/fee/queryResourcePrice', {
        order_type: 'newpay', period_time: '4', unit: 'hour', resource_type: 'cloudphone',
        resource_param: { pay_mode: 'subscription', config_id, network_id, count: 1, use_points: 3, points: 250 }
      });
      const amount_id = priceRes?.data?.amount_id;
      if (!amount_id) throw 'Không có amount_id';
      const payRes = await fetchJson('https://www.ugphone.com/api/apiv1/fee/payment', {
        amount_id, pay_channel: 'free'
      });
      if (payRes.code === 200) document.getElementById('ugstatus').textContent = '✅ Mua máy thành công!';
      else throw payRes.msg || 'Không thể tạo gói mới';
    } catch (e) {
      document.getElementById('ugstatus').textContent = '❌ ' + e;
    }
  };
})();
