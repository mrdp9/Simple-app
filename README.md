# **Mic**roservices **Dem**o: **Rea**ct + **Nod**e.js + **Fas**tAPI

## **Wh**at is **th**is?

This **pro**ject is a **sma**ll demo of an app **spl**it into **thr**ee services.

- **Fro**ntend: a **Rea**ct website, served by **Ngi**nx.
- **Aut**h service: a **Nod**e.js API.
- **Dat**a service: a **Pyt**hon FastAPI.

The **ser**vices **com**municate over a **net**work. The **dat**a service **ret**urns sample names; it does **not** use a database.

## **Pro**ject **str**ucture

```text
Simple-app/
├── frontend/       # React website and Nginx config
├── auth-service/   # Node.js API
├── data-service/   # FastAPI
├── docker-compose.yml
└── terraform/      # AWS infrastructure examples
```

## **How** a **req**uest **flo**ws

1. Your **bro**wser **loa**ds the website from the frontend.
2. The frontend **req**uests data from `/api/auth/` and `/api/data/`.
3. **Ngi**nx **for**wards those paths to the auth and data services.

With **Kubernetes**, the frontend can reach the APIs through their **int**ernal Service names. Usually, only the website needs to be **exp**osed to users.

## **Run** with **Doc**ker **Com**pose

From the project directory:

```bash
docker compose up --build
```

Open [http://localhost:3000](http://localhost:3000) to view the website.

To **che**ck the services:

- Auth: [http://localhost:4000/health](http://localhost:4000/health)
- Data: [http://localhost:8000/health](http://localhost:8000/health)

To **vie**w running containers and logs:

```bash
docker compose ps
docker compose logs
```

To **sto**p the app:

```bash
docker compose down
```

## **Whe**re to **loo**k

- **App code** shows routes, ports, and how services communicate.
- **Dockerfiles** show how each service is built and started.
- `package.json` and `requirements.txt` list application dependencies.
- `frontend/nginx.conf` shows how API requests are routed.
- `docker-compose.yml` shows how the containers run together locally.

For **Kubernetes**, focus first on **Deployments** (run app replicas), **Services** (stable networking), and **Ingress** (HTTP entry into the cluster). Start by understanding the app's ports and request flow before writing manifests.

## **Impor**tant **limi**tations

- The auth service is a **demo**, not real authentication.
- The data service returns **hard-coded** sample data.
- This project has **no database** or persistent application data.
- Docker Compose is for **local** orchestration; Kubernetes deployment is a separate learning step.

## **Next** steps

- Deploy the three services to a local Kubernetes cluster.
- Keep API Services internal; choose how users will access the website.
- Practice scaling a Deployment and observing what happens when a Pod fails.
- Later, explore the Terraform and GitHub Actions folders.

## **Lic**ense

This project is available under the [MIT License](LICENSE).
