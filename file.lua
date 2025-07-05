// ==UserScript==
// @name         Auto UGPhone Gia Bảo
// @namespace    https://ugphone.com/
// @version      3.0
// @description  Mua máy UGPhone 4H, đăng nhập + đăng xuất bằng LocalStorage, chọn server, hiển thị menu Conan đẹp mắt.
// @author       Gia Bảo
// @match        https://www.ugphone.com/toc-portal/*
// @icon         https://i.pinimg.com/originals/3b/9a/1e/3b9a1ec7b868b4b107bce28f783fb566.gif
// @grant        GM_xmlhttpRequest
// @connect      www.ugphone.com
// ==/UserScript==

(function () {
  'use strict';

  const servers = {
    "🇭🇰 HongKong": "1",
    "🇸🇬 Singapore": "2"
  };

  const gifUrl = "https://i.pinimg.com/originals/3b/9a/1e/3b9a1ec7b868b4b107bce28f783fb566.gif";

  const html = `
    <div id="gbaomenu" style="position:fixed;top:80px;right:20px;z-index:9999;padding:16px;border-radius:12px;background:white;box-shadow:0 0 12px rgba(0,0,0,0.3);width:300px;font-family:sans-serif">
      <img src="${gifUrl}" style="width:100%;border-radius:10px;margin-bottom:10px" />
      <textarea id="local-json" placeholder="Dán JSON localStorage ở đây..." style="width:100%;height:100px;margin-bottom:8px"></textarea>
      <div style="display:flex;gap:10px;margin-bottom:8px">
        <button id="btn-login" style="flex:1;padding:8px;border:none;border-radius:6px;background:#4caf50;color:white">Đăng nhập</button>
        <button id="btn-logout" style="flex:1;padding:8px;border:none;border-radius:6px;background:#f44336;color:white">Đăng xuất</button>
      </div>
      <select id="server-select" style="width:100%;padding:6px;border-radius:6px;margin-bottom:8px">
        ${Object.keys(servers).map(name => `<option value="${servers[name]}">${name}</option>`).join("")}
      </select>
      <button id="btn-buy" style="width:100%;padding:10px;background:#2196f3;color:white;border:none;border-radius:6px">🚀 Mua máy 4H</button>
      <div id="log" style="margin-top:10px;font-size:13px;color:#444"></div>
    </div>
  `;

  const div = document.createElement("div");
  div.innerHTML = html;
  document.body.appendChild(div);

  // Kéo thả menu
  const panel = document.getElementById("gbaomenu");
  panel.style.cursor = "move";
  let isDown = false, offset = {};
  panel.addEventListener("mousedown", (e) => {
    isDown = true;
    offset = { x: e.offsetX, y: e.offsetY };
  });
  document.addEventListener("mouseup", () => isDown = false);
  document.addEventListener("mousemove", (e) => {
    if (!isDown) return;
    panel.style.left = (e.pageX - offset.x) + "px";
    panel.style.top = (e.pageY - offset.y) + "px";
  });

  const log = (msg, color = "#333") => {
    document.getElementById("log").innerHTML = `<span style="color:${color}">${msg}</span>`;
  };

  document.getElementById("btn-login").onclick = () => {
    const txt = document.getElementById("local-json").value.trim();
    try {
      const obj = JSON.parse(txt);
      for (const [k, v] of Object.entries(obj)) {
        localStorage.setItem(k, typeof v === "object" ? JSON.stringify(v) : v);
      }
      log("✅ Đăng nhập thành công", "green");
      setTimeout(() => location.reload(), 1000);
    } catch (e) {
      log("❌ JSON không hợp lệ", "red");
    }
  };

  document.getElementById("btn-logout").onclick = () => {
    localStorage.clear();
    log("✅ Đăng xuất thành công", "orange");
    setTimeout(() => location.reload(), 1000);
  };

  document.getElementById("btn-buy").onclick = async () => {
    const mqtt = JSON.parse(localStorage.getItem("UGPHONE-MQTT") || "{}");
    const headers = {
      "content-type": "application/json",
      "access-token": mqtt.access_token || "",
      "login-id": mqtt.login_id || "",
      "terminal": "web",
      "lang": "vi"
    };
    if (!headers["access-token"]) return log("❌ Chưa đăng nhập", "red");

    try {
      const res = await fetch("https://www.ugphone.com/api/apiv1/fee/newPackage", {
        method: "POST",
        headers,
        body: "{}"
      });
      const json = await res.json();
      if (json.code !== 200) return log("❌ Không thể tạo gói mới: " + json.message, "red");

      // Lấy config
      const cfg = await fetch("https://www.ugphone.com/api/apiv1/info/configList2", { headers });
      const cfgJson = await cfg.json();
      const config_id = cfgJson?.data?.list?.[0]?.android_version?.[0]?.config_id;
      if (!config_id) return log("❌ Không tìm được config_id", "red");

      // Lấy gói
      const meal = await fetch("https://www.ugphone.com/api/apiv1/info/mealList", {
        method: "POST",
        headers,
        body: JSON.stringify({ config_id })
      });
      const mealJson = await meal.json();
      const subscription = mealJson?.data?.list?.[0]?.subscription?.[0];
      if (!subscription) return log("❌ Không có gói máy", "red");

      const amountReq = await fetch("https://www.ugphone.com/api/apiv1/fee/queryResourcePrice", {
        method: "POST",
        headers,
        body: JSON.stringify({
          order_type: "newpay",
          period_time: "4",
          unit: "hour",
          resource_type: "cloudphone",
          resource_param: {
            pay_mode: "subscription",
            config_id,
            network_id: subscription.network_id,
            count: 1,
            use_points: 3,
            points: 250
          }
        })
      });
      const amountJson = await amountReq.json();
      const amount_id = amountJson?.data?.amount_id;
      if (!amount_id) return log("❌ Không tìm thấy amount_id", "red");

      const pay = await fetch("https://www.ugphone.com/api/apiv1/fee/payment", {
        method: "POST",
        headers,
        body: JSON.stringify({ amount_id, pay_channel: "free" })
      });
      const payJson = await pay.json();
      if (payJson.code === 200) {
        log("✅ Mua máy 4H thành công!", "green");
        setTimeout(() => location.reload(), 1500);
      } else {
        log("❌ Mua máy thất bại: " + payJson.message, "red");
      }
    } catch (err) {
      log("❌ Lỗi: " + err.message, "red");
    }
  };
})();
