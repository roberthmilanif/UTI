from flask import Flask, render_template, request, redirect, url_for
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///cases.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

class Case(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    patient_name = db.Column(db.String(100), nullable=False)
    bed_number = db.Column(db.String(20), nullable=False)
    diagnosis = db.Column(db.String(200), nullable=False)
    notes = db.Column(db.Text, nullable=True)

    def __repr__(self):
        return f"<Case {self.patient_name} - Bed {self.bed_number}>"

@app.route('/')
def index():
    cases = Case.query.all()
    return render_template('index.html', cases=cases)

@app.route('/add', methods=['POST'])
def add_case():
    patient_name = request.form['patient_name']
    bed_number = request.form['bed_number']
    diagnosis = request.form['diagnosis']
    notes = request.form.get('notes', '')
    case = Case(patient_name=patient_name, bed_number=bed_number,
                diagnosis=diagnosis, notes=notes)
    db.session.add(case)
    db.session.commit()
    return redirect(url_for('index'))

@app.route('/delete/<int:case_id>')
def delete_case(case_id):
    case = Case.query.get_or_404(case_id)
    db.session.delete(case)
    db.session.commit()
    return redirect(url_for('index'))

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True)
