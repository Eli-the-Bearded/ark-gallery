var ac = {
  // (A) ATTACH AUTOCOMPLETE TO INPUT FIELD
  // options
  //  target : target field
  //  data : suggestion data (ARRAY), or URL (STRING)
  //  post : optional, extra data to send to server
  //  delay : optional, delay before suggestion, default 500ms
  //  min : optional, minimum characters to fire suggestion, default 2
  instances : [], // autocomplete instances
  attach : (options) => {
    // (A1) NEW AUTOCOMPLETE INSTANCE
    ac.instances.push({
      target: options.target, // HTML input field
      parent: options.target.parentElement, // HTML input parent
      wrapper: document.createElement("div"), // HTML suggestion wrapper
      suggest: document.createElement("div"), // HTML suggestion box
      timer: null, // Autosuggest timer
      data: options.data,
      post: options.post ? options.post : null,
      delay: options.delay ? options.delay : 200,
      min: options.min ? options.min : 2
    });
    let iid = ac.instances.length-1,
        instance = ac.instances[iid];

    // (A2) ATTACH AUTOCOMPLETE HTML
    instance.parent.insertBefore(instance.wrapper, instance.target);
    instance.wrapper.classList.add("acWrap");
    instance.wrapper.appendChild(instance.target);
    instance.wrapper.appendChild(instance.suggest);
    instance.suggest.classList.add("acSuggest");

    // (A3) KEY PRESS LISTENER
    instance.target.addEventListener("keyup", (evt) => {
      // CLEAR OLD TIMER & SUGGESTION BOX
      if (instance.timer != null) { window.clearTimeout(instance.timer); }
      instance.suggest.innerHTML = "";
      instance.suggest.style.display = "none";

      // CREATE NEW TIMER - FETCH DATA FROM SERVER OR STRING
      if (instance.target.value.length >= instance.min) {
        if (typeof instance.data == "string") {
          instance.timer = setTimeout(() => { ac.fetch(iid); }, instance.delay);
        } else {
          instance.timer = setTimeout(() => { ac.filter(iid); }, instance.delay);
        }
      }
    });
  },

  // (B) DRAW SUGGESTIONS FROM ARRAY
  filter : (id) => {
    // (B1) GET INSTANCE + DATA
    let instance = ac.instances[id],
        search = instance.target.value.toLowerCase(),
        multi = typeof instance.data[0]=="object",
        results = [];

    // (B2) FILTER APPLICABLE SUGGESTIONS
    for (let i of instance.data) {
      let entry = multi ? i.D : i ;
      if (entry.toLowerCase().indexOf(search) != -1) { results.push(i); }
    }

    // (B3) DRAW SUGGESTIONS
    ac.draw(id, results.length==0 ? null : results);
  },

  // (C) AJAX FETCH SUGGESTIONS FROM SERVER
  fetch : (id) => {
    // (C1) INSTANCE & FORM DATA
    let instance = ac.instances[id],
        data = new FormData();
    data.append("search", instance.target.value);
    if (instance.post !== null) { for (let i in instance.post) {
      data.append(i, instance.post[i]);
    }}

    // (C2) FETCH
    fetch(instance.data, { method: "POST", body: data })
    .then((res) => {
      if (res.status != 200) { throw new Error("Bad Server Response"); }
      return res.json();
    })
    .then((res) => { ac.draw(id, res); })
    .catch((err) => { console.error(err); });
  },

  // (D) DRAW AUTOSUGGESTION
  open : null, // Currently open autocomplete
  draw : (id, results) => {
    // (D1) GET INSTANCE
    let instance = ac.instances[id];
    ac.open = id;

    // (D2) DRAW RESULTS
    if (results == null) { ac.close(); }
    else {
      instance.suggest.innerHTML = "";
      let multi = typeof results[0]=="object",
          list = document.createElement("ul"), row, entry;
      for (let i of results) {
        row = document.createElement("li");
        row.innerHTML = multi ? i.D : i;
        if (multi) {
          entry = {...i};
          delete entry.D;
          row.dataset.multi = JSON.stringify(entry);
        }
        row.onclick = function () { ac.select(id, this); };
        list.appendChild(row);
      }
      instance.suggest.appendChild(list);
      instance.suggest.style.display = "block";
    }
  },

  // (E) ON SELECTING A SUGGESTION
  select : (id, el) => {
    ac.instances[id].target.value = el.innerHTML;
    if (el.dataset.multi !== undefined) {
      let multi = JSON.parse(el.dataset.multi);
      for (let i in multi) {
        document.getElementById(i).value = multi[i];
      }
    }
    ac.close();
  },

  // (F) CLOSE AUTOCOMPLETE
  close : () => { if (ac.open != null) {
    let instance = ac.instances[ac.open];
    instance.suggest.innerHTML = "";
    instance.suggest.style.display = "none";
    ac.open = null;
  }},

  // (G) CLOSE AUTOCOMPLETE IF USER CLICKS ANYWHERE OUTSIDE
  checkclose : (evt) => { if (ac.open != null) {
    let instance = ac.instances[ac.open];
    if (instance.target.contains(evt.target)==false &&
        instance.suggest.contains(evt.target)==false) { ac.close(); }
  }}
};
document.addEventListener("click", ac.checkclose);
