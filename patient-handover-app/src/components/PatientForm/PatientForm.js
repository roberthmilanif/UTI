import React, { useState, useContext, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { PatientContext } from '../../contexts/PatientContext';
import './PatientForm.css';

const initialFormState = {
  name: '',
  dateOfBirth: '',
  medicalHistory: '',
  medications: '',
  labResults: '',
  evolutionNotes: '',
};

function PatientForm() {
  const { addPatient, editPatient, selectedPatient, setSelectedPatientId } = useContext(PatientContext);
  const [formData, setFormData] = useState(initialFormState);
  const [isEditing, setIsEditing] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    if (selectedPatient) {
      setFormData({
        name: selectedPatient.name || '',
        dateOfBirth: selectedPatient.dateOfBirth || '',
        medicalHistory: selectedPatient.medicalHistory || '',
        medications: selectedPatient.medications || '',
        labResults: selectedPatient.labResults || '',
        evolutionNotes: selectedPatient.evolutionNotes || '',
      });
      setIsEditing(true);
    } else {
      setFormData(initialFormState);
      setIsEditing(false);
    }
  }, [selectedPatient]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prevState => ({
      ...prevState,
      [name]: value,
    }));
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (isEditing && selectedPatient) {
      editPatient({ ...formData, id: selectedPatient.id });
    } else {
      addPatient(formData);
    }
    setSelectedPatientId(null);
    setFormData(initialFormState);
    setIsEditing(false);
    navigate('/');
  };

  const handleCancel = () => {
    setSelectedPatientId(null);
    setFormData(initialFormState);
    setIsEditing(false);
    navigate('/');
  };

  return (
    <div className="patient-form-container">
      <h2>{isEditing ? 'Editar Detalhes do Paciente' : 'Adicionar Novo Paciente'}</h2> {/* Edit Patient Details / Add New Patient */}
      <form onSubmit={handleSubmit} className="patient-form">
        <div className="form-group">
          <label htmlFor="name">Nome:</label> {/* Name: */}
          <input
            type="text"
            id="name"
            name="name"
            value={formData.name}
            onChange={handleChange}
            required
          />
        </div>
        <div className="form-group">
          <label htmlFor="dateOfBirth">Data de Nascimento:</label> {/* Date of Birth: */}
          <input
            type="date"
            id="dateOfBirth"
            name="dateOfBirth"
            value={formData.dateOfBirth}
            onChange={handleChange}
          />
        </div>
        <div className="form-group">
          <label htmlFor="medicalHistory">Histórico Médico:</label> {/* Medical History: */}
          <textarea
            id="medicalHistory"
            name="medicalHistory"
            value={formData.medicalHistory}
            onChange={handleChange}
            rows="3"
          />
        </div>
        <div className="form-group">
          <label htmlFor="medications">Medicamentos:</label> {/* Medications: */}
          <textarea
            id="medications"
            name="medications"
            value={formData.medications}
            onChange={handleChange}
            rows="3"
            placeholder="Lisinopril 10mg OD..." // Placeholder can remain or be translated
          />
        </div>
        <div className="form-group">
          <label htmlFor="labResults">Resultados de Exames:</label> {/* Lab Results: */}
          <textarea
            id="labResults"
            name="labResults"
            value={formData.labResults}
            onChange={handleChange}
            rows="3"
            placeholder="HbA1c: 7.5% (2023-10-01)..." // Placeholder can remain or be translated
          />
        </div>
        <div className="form-group">
          <label htmlFor="evolutionNotes">Notas de Evolução:</label> {/* Evolution Notes: */}
          <textarea
            id="evolutionNotes"
            name="evolutionNotes"
            value={formData.evolutionNotes}
            onChange={handleChange}
            rows="5"
          />
        </div>
        <div className="form-actions">
          <button type="submit" className="submit-button">
            {isEditing ? 'Salvar Alterações' : 'Adicionar Paciente'} {/* Save Changes / Add Patient */}
          </button>
          <button type="button" onClick={handleCancel} className="cancel-button">
            Cancelar {/* Cancel */}
          </button>
        </div>
      </form>
    </div>
  );
}

export default PatientForm;
